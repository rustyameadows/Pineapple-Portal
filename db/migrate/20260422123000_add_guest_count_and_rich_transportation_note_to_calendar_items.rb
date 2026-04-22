class AddGuestCountAndRichTransportationNoteToCalendarItems < ActiveRecord::Migration[8.0]
  def up
    add_column :calendar_items, :guest_count, :string
    change_column :calendar_items, :transportation_note, :text
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "Cannot safely narrow transportation_note back to 255 characters after rich text notes are in use."
  end
end
