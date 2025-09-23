module Client
  module Calendars
    class SelectedView
      attr_reader :view, :calendar

      def self.run_of_show(calendar)
        new(calendar:, view: nil)
      end

      def initialize(calendar:, view:)
        @calendar = calendar
        @view = view
      end

    def name
      view&.name || calendar.name
    end

    def description
      return view.description if view&.description.present?
      return calendar.description if run_of_show? && calendar.description.present?

      "Full schedule overview for your event."
    end

    def hide_locked?
      view&.hide_locked? || false
    end

      def tag_filter
        Array(view&.tag_filter)
      end

      def client_visible?
        true
      end

    def slug
      view&.slug || "run-of-show"
    end

    def run_of_show?
      view.nil?
    end
    end
  end
end
