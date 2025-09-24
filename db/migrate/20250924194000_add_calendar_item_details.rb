class AddCalendarItemDetails < ActiveRecord::Migration[8.0]
  def change
    add_column :calendar_items, :vendor_name, :string
    add_column :calendar_items, :location_name, :string
    add_column :calendar_items, :status, :string, null: false, default: "planned"
    add_column :calendar_items, :additional_team_members, :string

    add_index :calendar_items, :status
  end
end
