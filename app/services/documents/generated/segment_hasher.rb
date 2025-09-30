require "digest"

module Documents
  module Generated
    class SegmentHasher
      class << self
        def call(segment)
          new(segment).call
        end
      end

      def initialize(segment)
        @segment = segment
      end

      def call
        Digest::SHA256.hexdigest(JSON.dump(payload))
      end

      private

      attr_reader :segment

      def payload
        {
          document_logical_id: segment.document_logical_id,
          kind: segment.kind,
          title: segment.title,
          source_ref: canonical_source_ref,
          spec: canonical_spec
        }
      end

      def canonical_source_ref
        deep_sort(segment.source_ref)
      end

      def canonical_spec
        deep_sort(segment.spec)
      end

      def deep_sort(value)
        case value
        when Hash
          value.keys.sort.each_with_object({}) do |key, result|
            result[key] = deep_sort(value[key])
          end
        when Array
          value.map { |entry| deep_sort(entry) }
        else
          value
        end
      end
    end
  end
end
