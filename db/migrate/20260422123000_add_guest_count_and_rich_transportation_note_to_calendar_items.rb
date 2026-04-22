class AddGuestCountAndRichTransportationNoteToCalendarItems < ActiveRecord::Migration[8.0]
  def up
    add_column :calendar_items, :guest_count, :string
    change_column :calendar_items, :transportation_note, :text
  end

  def down
    change_column :calendar_items, :transportation_note, :string
    remove_column :calendar_items, :guest_count
  end
end
