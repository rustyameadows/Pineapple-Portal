module Documents
  module Generated
    class BuildRunner
      def initialize(build:, segment_storage: R2Storage.new, document_storage: R2::Storage.new)
        @build = build
        @segment_storage = segment_storage
        @document_storage = document_storage
      end

      def call
        Compiler.new(
          definition_document: build.document,
          build: build,
          built_by_user: build.built_by_user,
          segment_storage: segment_storage,
          document_storage: document_storage,
          page_numbers: build.page_numbers
        ).call
      rescue Compiler::CancelledError => error
        raise CancelledError, error.message
      rescue Compiler::CompileError => error
        raise CompileError, error.message
      end

      private

      attr_reader :build, :segment_storage, :document_storage

      class CompileError < StandardError; end
      class CancelledError < StandardError; end
    end
  end
end
