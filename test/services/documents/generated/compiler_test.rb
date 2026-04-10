require "test_helper"

module Documents
  module Generated
    class CompilerTest < ActiveSupport::TestCase
      class PageNumbererStub
        class << self
          attr_accessor :calls
        end

        def initialize(pdf_data:, entries:, overlay_renderer: nil)
          self.class.calls ||= []
          self.class.calls << {
            pdf_data: pdf_data,
            entries: entries,
            overlay_renderer: overlay_renderer
          }
        end

        def call
          "PDF_WITH_NUMBERS"
        end
      end

      class SegmentStorageStub
        def download(_key)
          "segment-pdf"
        end
      end

      class DocumentStorageStub
        attr_accessor :download_data
        attr_reader :downloaded_key, :uploaded_key, :uploaded_data, :uploaded_content_type

        def upload_io(key, data, content_type:)
          @uploaded_key = key
          @uploaded_data = data
          @uploaded_content_type = content_type
        end

        def download(key)
          @downloaded_key = key
          StringIO.new(download_data.to_s)
        end
      end

      class BuildSpy
        attr_reader :progress_calls
        attr_accessor :build_id

        def initialize(build_id: SecureRandom.uuid)
          @build_id = build_id
          @progress_calls = []
        end

        def report_progress!(**kwargs)
          @progress_calls << kwargs
        end

        def persisted?
          false
        end

        def destroyed?
          false
        end

        def cancelled?
          false
        end
      end

      class FakeCombinePDF
        attr_reader :label, :pages

        def initialize(label, pages_count: 1)
          @label = label
          @pages = Array.new(pages_count) { Object.new }
        end

        def <<(other)
          @pages.concat(other.pages)
        end

        def to_pdf
          case label
          when :stitch
            "PDF_WITHOUT_NUMBERS"
          when :final
            "PDF_WITH_NUMBERS"
          else
            "PDF_WITHOUT_NUMBERS"
          end
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
          packets_portal_visible: false,
          source: "packet"
        )

        @segment = DocumentSegment.create!(
          document_logical_id: @definition_document.logical_id,
          position: 1,
          kind: DocumentSegment::KINDS[:pdf_asset],
          title: "Segment",
          source_ref: {
            "document_id" => documents(:contract_v1).id,
            "logical_id" => documents(:contract_v1).logical_id
          },
          spec: { "kind" => DocumentSegment::KINDS[:pdf_asset] }
        )

        @segment.update!(
          render_hash: "segment-hash",
          cached_pdf_key: "segments/stub.pdf",
          cached_pdf_generated_at: Time.current,
          cached_page_count: 1,
          cached_file_size: 10
        )

        @build = @definition_document.builds.create!(
          status: DocumentBuild::STATUSES[:pending],
          build_id: SecureRandom.uuid
        )

        @segment_storage = SegmentStorageStub.new
        @document_storage = DocumentStorageStub.new
        PageNumbererStub.calls = []
      end

      test "compiler leaves PDF untouched without page numbers flag" do
        result = execute_compiler(page_numbers: false)

        assert_equal "PDF_WITHOUT_NUMBERS", @document_storage.uploaded_data
        assert_equal "application/pdf", @document_storage.uploaded_content_type
        assert_equal 1, result.page_count
      end

      test "compiler applies page numbers when flag enabled" do
        result = execute_compiler(page_numbers: true)

        assert_equal "PDF_WITH_NUMBERS", @document_storage.uploaded_data
        assert_equal "application/pdf", @document_storage.uploaded_content_type
        assert_equal 1, result.page_count

        call = PageNumbererStub.calls.last
        assert_equal "PDF_WITHOUT_NUMBERS", call[:pdf_data]
        assert_equal [@segment], call[:entries].map { |entry| entry[:source] }
      end

      test "compiler defaults compiled packets visibility to hidden" do
        @definition_document.update!(packets_portal_visible: true)

        result = execute_compiler(page_numbers: false)

        assert_not result.compiled_document.packets_portal_visible?
      end

      test "compiler promotes the current live working pdf into a numbered snapshot when it is fresh" do
        manifest_hash = segment_manifest_hash(@segment, "segment-hash")

        @definition_document.update!(
          working_storage_uri: "documents/#{@event.id}/#{@definition_document.logical_id}/working/generated-packet-working.pdf",
          working_manifest_hash: manifest_hash,
          working_rendered_at: Time.current,
          working_status: Document::WORKING_STATUSES[:fresh]
        )
        @document_storage.download_data = "WORKING_PDF"

        result = execute_compiler(page_numbers: true)

        assert_equal @definition_document.working_storage_uri, @document_storage.downloaded_key
        assert_equal "WORKING_PDF", @document_storage.uploaded_data
        assert_equal manifest_hash, result.manifest_hash
        assert_equal [], PageNumbererStub.calls
      end

      test "compiler rebuilds an unnumbered snapshot instead of reusing the numbered working pdf" do
        manifest_hash = segment_manifest_hash(@segment, "segment-hash")

        @definition_document.update!(
          working_storage_uri: "documents/#{@event.id}/#{@definition_document.logical_id}/working/generated-packet-working.pdf",
          working_manifest_hash: manifest_hash,
          working_rendered_at: Time.current,
          working_status: Document::WORKING_STATUSES[:fresh]
        )
        @document_storage.download_data = "WORKING_PDF"

        result = execute_compiler(page_numbers: false)

        assert_nil @document_storage.downloaded_key
        assert_equal "PDF_WITHOUT_NUMBERS", @document_storage.uploaded_data
        assert_equal manifest_hash, result.manifest_hash
      end

      test "compiler reports progress stages for a numbered snapshot build" do
        build = BuildSpy.new

        execute_compiler(page_numbers: true, build: build)

        assert_equal [
          { stage: :preparing_pdf },
          { stage: :rendering_entries, current: 1, total: 1 },
          { stage: :assembling_pdf },
          { stage: :adding_page_numbers },
          { stage: :uploading_pdf },
          { stage: :finalizing_pdf }
        ], build.progress_calls
      end

      test "compiler reports live pdf reuse progress when it can promote the working copy" do
        manifest_hash = segment_manifest_hash(@segment, "segment-hash")
        build = BuildSpy.new

        @definition_document.update!(
          working_storage_uri: "documents/#{@event.id}/#{@definition_document.logical_id}/working/generated-packet-working.pdf",
          working_manifest_hash: manifest_hash,
          working_rendered_at: Time.current,
          working_status: Document::WORKING_STATUSES[:fresh]
        )
        @document_storage.download_data = "WORKING_PDF"

        execute_compiler(page_numbers: true, build: build)

        assert_equal [
          { stage: :preparing_pdf },
          { stage: :preparing_pdf, message: "Using the current live PDF" },
          { stage: :uploading_pdf },
          { stage: :finalizing_pdf }
        ], build.progress_calls
      end

      private

      def execute_compiler(page_numbers:, build: @build)
        SegmentHasher.stub :call, ->(_segment) { "segment-hash" } do
          PageNumberer.stub :new, ->(**kwargs) { PageNumbererStub.new(**kwargs) } do
            stub_combine_pdf do
              compiler = Compiler.new(
                definition_document: @definition_document,
                build: build,
                built_by_user: nil,
                segment_storage: @segment_storage,
                document_storage: @document_storage,
                page_numbers: page_numbers
              )
              compiler.call
            end
          end
        end
      end

      def stub_combine_pdf
        CombinePDF.stub :new, -> { FakeCombinePDF.new(:stitch, pages_count: 0) } do
          CombinePDF.stub :parse, ->(input) { fake_parsed_pdf_for(input) } do
            yield
          end
        end
      end

      def fake_parsed_pdf_for(input)
        case input
        when "segment-pdf"
          FakeCombinePDF.new(:segment)
        when "WORKING_PDF"
          FakeCombinePDF.new(:apply)
        when "PDF_WITHOUT_NUMBERS"
          FakeCombinePDF.new(:apply)
        when "PDF_WITH_NUMBERS"
          FakeCombinePDF.new(:final)
        else
          FakeCombinePDF.new(:other)
        end
      end

      def segment_manifest_hash(segment, render_hash)
        Digest::SHA256.hexdigest(JSON.dump([
          {
            entry_key: "segment:#{segment.id}",
            source_key: "#{segment.class.name}:#{segment.id}",
            render_hash: render_hash
          }
        ]))
      end
    end
  end
end
