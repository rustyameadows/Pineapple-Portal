module Calendars
  class ViewFilter
    def initialize(calendar:, view:)
      @calendar = calendar
      @view = view
    end

    def items
      @items ||= begin
        scope = calendar.calendar_items.includes(:event_calendar_tags, :relative_anchor).ordered
        scope.select do |item|
          next false if view.hide_locked? && item.locked?
          next true if tag_ids.empty?

          (item.event_calendar_tag_ids & tag_ids).any?
        end
      end
    end

    private

    attr_reader :calendar, :view

    def tag_ids
      @tag_ids ||= Array(view.tag_filter).map(&:to_i)
    end
  end
end
