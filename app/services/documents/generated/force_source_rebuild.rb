module Documents
  module Generated
    class ForceSourceRebuild
      class Error < StandardError; end

      Result = Struct.new(:consumers, :queued_builds, keyword_init: true) do
        def consumer_count
          consumers.size
        end
      end

      def initialize(source:)
        @source = source
      end

      def call
        consumers = nil

        GeneratedPacketSource.transaction do
          locked_source = lock_source!
          validate_source!(locked_source)

          consumers = packet_consumers(locked_source).order(:id).lock.to_a
          if consumers.empty?
            raise Error, "This page is not used by any packets."
          end

          locked_source.clear_cached_render!
          consumers.each(&:clear_working_copy!)
        end

        queued_builds = consumers.map do |consumer|
          WorkingCopyRefresh.enqueue(consumer)
        end

        Result.new(consumers: consumers, queued_builds: queued_builds)
      end

      private

      attr_reader :source

      def lock_source!
        unless source&.persisted?
          raise Error, "Force builds require a saved page."
        end

        GeneratedPacketSource.lock.find(source.id)
      rescue ActiveRecord::RecordNotFound
        raise Error, "Force builds require a saved page."
      end

      def validate_source!(locked_source)
        unless locked_source.html_view?
          raise Error, "Only system-generated pages can be force built."
        end

        unless locked_source.cached?
          raise Error, "Only cached pages can be force built."
        end
      end

      def packet_consumers(locked_source)
        PacketConsumerResolver.new(event: locked_source.event).for_source(locked_source)
      end
    end
  end
end
