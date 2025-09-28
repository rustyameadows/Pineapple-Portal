require "test_helper"

module Documents
  module Generated
    class CompilerTest < ActiveSupport::TestCase
      class SegmentStorageStub
        def download(_key)
          "segment-pdf"
        end
      end

      class DocumentStorageStub
        attr_reader :uploaded_key, :uploaded_data, :uploaded_content_type

        def upload_io(key, data, content_type:)
          @uploaded_key = key
          @uploaded_data = data
          @uploaded_content_type = content_type
        end
      end

      class FakeCombinePDF
        class << self
          attr_accessor :last_number_pages_options
        end

        attr_reader :label, :pages

        def initialize(label, pages_count: 1)
          @label = label
          @pages = Array.new(pages_count) { Object.new }
          @numbered = false
        end

        def <<(other)
          @pages.concat(other.pages)
        end

        def number_pages(**options)
          self.class.last_number_pages_options = options
          @numbered = true
        end

        def numbered?
          @numbered
        end

        def to_pdf
          label == :apply && numbered? ? "PDF_WITH_NUMBERS" : "PDF_WITHOUT_NUMBERS"
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

        @segment = DocumentSegment.create!(
          document_logical_id: @definition_document.logical_id,
          position: 1,
          kind: DocumentSegment::KINDS[:pdf_asset],
          title: "Segment",
          source_ref: { "document_id" => documents(:contract_v1).id },
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
        FakeCombinePDF.last_number_pages_options = nil
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

        options = FakeCombinePDF.last_number_pages_options
        assert_equal :bottom_right, options[:location]
        assert_equal "pg. %s", options[:number_format]
        assert_equal 1, options[:start_at]
        assert_equal 10, options[:font_size]
        assert_equal 10, options[:margin_from_side]
        assert_equal 12, options[:y]
        assert_equal :right, options[:text_align]

        assert_nil options[:font]
      end

      private

      def execute_compiler(page_numbers:)
        SegmentHasher.stub :call, ->(_segment) { "segment-hash" } do
          stub_combine_pdf do
            compiler = Compiler.new(
              definition_document: @definition_document,
              build: @build,
              built_by_user: nil,
              segment_storage: @segment_storage,
              document_storage: @document_storage,
              page_numbers: page_numbers
            )
            compiler.call
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
        when "PDF_WITHOUT_NUMBERS"
          FakeCombinePDF.new(:apply)
        when "PDF_WITH_NUMBERS"
          FakeCombinePDF.new(:final)
        else
          FakeCombinePDF.new(:other)
        end
      end
    end
  end
end
