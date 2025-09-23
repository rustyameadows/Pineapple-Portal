module Calendars
  module Commands
    class ReorderItems
      Result = Struct.new(:reordered_ids, keyword_init: true)

      def initialize(calendar:)
        @calendar = calendar
      end

      def call(order: [])
        ids = order.map(&:to_i)
        return Result.new(reordered_ids: []) if ids.empty?

        ActiveRecord::Base.transaction do
          ids.each_with_index do |item_id, index|
            item = calendar.calendar_items.find_by(id: item_id)
            next unless item

            item.update_columns(position: index) # rubocop:disable Rails/SkipsModelValidations
          end
        end

        Result.new(reordered_ids: ids)
      end

      private

      attr_reader :calendar
    end
  end
end
