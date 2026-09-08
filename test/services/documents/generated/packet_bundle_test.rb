require "test_helper"

module Documents
  module Generated
    class PacketBundleTest < ActiveSupport::TestCase
      class SegmentStorageStub
        def download(_key)
          "segment-pdf"
        end
      end

      class FakeCombinePDF
        attr_reader :pages

        def initialize(pages_count: 1)
          @pages = Array.new(pages_count) { Object.new }
        end

        def <<(other)
          @pages.concat(other.pages)
        end

        def to_pdf
          "COMPILED_PDF"
        end
      end

      class PageNumbererStub
        def initialize(pdf_data:, entries:, overlay_renderer: nil)
          @pdf_data = pdf_data
          @entries = entries
          @overlay_renderer = overlay_renderer
        end

        def call
          "NUMBERED_PDF"
        end
      end

      setup do
        @event = events(:one)
        @definition_document = @event.documents.create!(
          title: "Generated Packet",
          doc_kind: Document::DOC_KINDS[:generated],
          logical_id: SecureRandom.uuid,
          version: 1,
          is_latest: false,
          client_visible: false,
          source: "packet"
        )

        @segment_one = create_cached_segment("Segment One", 1)
        @segment_two = create_cached_segment("Segment Two", 2)
        @progress_calls = []
      end

      test "packet bundle reports rendering and numbering progress" do
        SegmentHasher.stub :call, ->(_segment) { "segment-hash" } do
          PageNumberer.stub :new, ->(**kwargs) { PageNumbererStub.new(**kwargs) } do
            stub_combine_pdf do
              bundle = PacketBundle.new(
                definition_document: @definition_document,
                segment_storage: SegmentStorageStub.new,
                page_numbers: true,
                progress_reporter: ->(**kwargs) { @progress_calls << kwargs }
              )

              result = bundle.call

              assert_equal "NUMBERED_PDF", result.pdf_data
            end
          end
        end

        assert_equal [
          { stage: :rendering_entries, message: "Rendering pages 1/2: Segment One", current: 1, total: 2 },
          { stage: :rendering_entries, message: "Rendering pages 2/2: Segment Two", current: 2, total: 2 },
          { stage: :assembling_pdf, message: "Assembling PDF 1/2: Segment One", current: 1, total: 2 },
          { stage: :assembling_pdf, message: "Assembling PDF 2/2: Segment Two", current: 2, total: 2 },
          { stage: :adding_page_numbers }
        ], @progress_calls
      end

      test "packet bundle identifies and records a layered PDF that cannot be assembled" do
        parse_calls = 0
        layered_pdf_error = CombinePDF::ParsingError.new(
          "Optional Content PDF files aren't supported and their pages cannot be safely extracted."
        )

        SegmentHasher.stub :call, ->(_segment) { "segment-hash" } do
          CombinePDF.stub :new, -> { FakeCombinePDF.new(pages_count: 0) } do
            CombinePDF.stub :parse, lambda { |_input|
              parse_calls += 1
              raise layered_pdf_error if parse_calls == 2

              FakeCombinePDF.new
            } do
              error = assert_raises(Compiler::CompileError) do
                PacketBundle.new(
                  definition_document: @definition_document,
                  segment_storage: SegmentStorageStub.new,
                  progress_reporter: ->(**kwargs) { @progress_calls << kwargs }
                ).call
              end

              assert_equal(
                "PDF \"Segment Two\" could not be added to the packet. " \
                "This PDF contains layers (optional content) and cannot be safely combined. " \
                "Flatten or re-export it, upload a new version, then rebuild the live PDF.",
                error.message
              )
            end
          end
        end

        assert_nil @segment_one.reload.last_render_error
        assert_equal PacketBundle::LAYERED_PDF_ERROR, @segment_two.reload.last_render_error
        assert_equal(
          { stage: :assembling_pdf, message: "Assembling PDF 2/2: Segment Two", current: 2, total: 2 },
          @progress_calls.last
        )
      end

      test "packet bundle clears a recorded source error after successful assembly" do
        @segment_one.update!(last_render_error: PacketBundle::LAYERED_PDF_ERROR)

        SegmentHasher.stub :call, ->(_segment) { "segment-hash" } do
          stub_combine_pdf do
            PacketBundle.new(
              definition_document: @definition_document,
              segment_storage: SegmentStorageStub.new
            ).call
          end
        end

        assert_nil @segment_one.reload.last_render_error
      end

      private

      def create_cached_segment(title, position)
        segment = DocumentSegment.create!(
          document_logical_id: @definition_document.logical_id,
          position: position,
          kind: DocumentSegment::KINDS[:pdf_asset],
          title: title,
          source_ref: {
            "document_id" => documents(:contract_v1).id,
            "logical_id" => documents(:contract_v1).logical_id
          },
          spec: { "kind" => DocumentSegment::KINDS[:pdf_asset] }
        )

        segment.update!(
          render_hash: "segment-hash",
          cached_pdf_key: "segments/#{title.parameterize}.pdf",
          cached_pdf_generated_at: Time.current,
          cached_page_count: 1,
          cached_file_size: 10
        )

        segment
      end

      def stub_combine_pdf
        CombinePDF.stub :new, -> { FakeCombinePDF.new(pages_count: 0) } do
          CombinePDF.stub :parse, ->(_input) { FakeCombinePDF.new } do
            yield
          end
        end
      end
    end
  end
end
