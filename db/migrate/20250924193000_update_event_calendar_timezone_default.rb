class UpdateEventCalendarTimezoneDefault < ActiveRecord::Migration[8.0]
  def change
    change_column_default :event_calendars, :timezone, from: "UTC", to: "America/New_York"
    reversible do |dir|
      dir.up do
        calendar_class = Class.new(ActiveRecord::Base) do
          self.table_name = "event_calendars"
        end

        calendar_class.reset_column_information
        calendar_class.where(timezone: [nil, ""]).update_all(timezone: "America/New_York")
      end
    end
  end
end
