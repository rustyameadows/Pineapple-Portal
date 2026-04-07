class AddTransportationNoteToCalendarItems < ActiveRecord::Migration[8.0]
  def change
    add_column :calendar_items, :transportation_note, :string
  end
end
