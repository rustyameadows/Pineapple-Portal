module Calendars
  class GridBulkUpdater
    Result = Data.define(:success, :message) do
      def success?
        success
      end
    end

    def initialize(calendar:, item_ids:, params:)
      @calendar = calendar
      @item_ids = item_ids
      @params = params
    end

    def call
      return Result.new(success: false, message: "Select at least one item.") if items.empty?

      performed = case action
                  when "set_status"
                    apply_status
                  when "set_locked"
                    apply_locked
                  when "add_tags"
                    apply_tag_additions
                  when "remove_tags"
                    apply_tag_removals
                  when "set_vendor"
                    apply_vendor_update
                  when "clear_vendor"
                    apply_vendor_clear
                  when "set_location"
                    apply_location_update
                  when "clear_location"
                    apply_location_clear
                  when "delete_items"
                    apply_deletions
                  else
                    return Result.new(success: false, message: "Choose a bulk action.")
                  end

      return Result.new(success: false, message: performed) if performed.is_a?(String)

      Calendars::CascadeScheduler.new(calendar).call
      Result.new(success: true, message: success_message)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success: false, message: e.record.errors.full_messages.to_sentence.presence || "Unable to update selected items.")
    end

    private

    attr_reader :calendar, :item_ids, :params

    def items
      @items ||= calendar.calendar_items.where(id: item_ids)
    end

    def action
      params[:bulk_action].to_s
    end

    def apply_status
      status = params[:status].to_s
      return "Select a valid status." unless CalendarItem.statuses.key?(status)

      items.find_each { |item| item.update!(status: status) }
      @success_message = "Status updated for #{items.count} item#{'s' if items.count != 1}."
      true
    end

    def apply_locked
      value = ActiveModel::Type::Boolean.new.cast(params[:locked])
      items.find_each { |item| item.update!(locked: value) }
      state = value ? "locked" : "unlocked"
      @success_message = "#{items.count} item#{'s' if items.count != 1} #{state}."
      true
    end

    def apply_tag_additions
      tag_ids = permitted_tag_ids
      return "Select at least one tag." if tag_ids.empty?

      items.find_each do |item|
        combined = (item.event_calendar_tag_ids + tag_ids).uniq
        item.update!(event_calendar_tag_ids: combined)
      end
      @success_message = "Tags added to #{items.count} item#{'s' if items.count != 1}."
      true
    end

    def apply_tag_removals
      tag_ids = permitted_tag_ids
      return "Select at least one tag." if tag_ids.empty?

      items.find_each do |item|
        remaining = item.event_calendar_tag_ids - tag_ids
        item.update!(event_calendar_tag_ids: remaining)
      end
      @success_message = "Tags removed from #{items.count} item#{'s' if items.count != 1}."
      true
    end

    def apply_vendor_update
      vendor_name = params[:vendor_name].to_s.strip
      return "Enter a vendor." if vendor_name.blank?

      items.find_each { |item| item.update!(vendor_name:) }
      @success_message = "Vendor updated for #{items.count} item#{'s' if items.count != 1}."
      true
    end

    def apply_vendor_clear
      items.find_each { |item| item.update!(vendor_name: nil) }
      @success_message = "Vendor cleared for #{items.count} item#{'s' if items.count != 1}."
      true
    end

    def apply_location_update
      location_name = params[:location_name].to_s.strip
      return "Enter a location." if location_name.blank?

      items.find_each { |item| item.update!(location_name:) }
      @success_message = "Location updated for #{items.count} item#{'s' if items.count != 1}."
      true
    end

    def apply_location_clear
      items.find_each { |item| item.update!(location_name: nil) }
      @success_message = "Location cleared for #{items.count} item#{'s' if items.count != 1}."
      true
    end

    def apply_deletions
      count = items.count
      items.destroy_all
      @items = CalendarItem.none
      @success_message = "#{count} item#{'s' if count != 1} removed."
      true
    end

    def permitted_tag_ids
      available = calendar.event_calendar_tags.pluck(:id)
      Array(params[:tag_ids]).map(&:to_i).select { |id| available.include?(id) }
    end

    def success_message
      @success_message || "Updates applied."
    end
  end
end
