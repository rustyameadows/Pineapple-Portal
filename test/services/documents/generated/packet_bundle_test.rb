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
          { stage: :rendering_entries, current: 1, total: 2 },
          { stage: :rendering_entries, current: 2, total: 2 },
          { stage: :assembling_pdf },
          { stage: :adding_page_numbers }
        ], @progress_calls
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
