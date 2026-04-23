class CreateEventKeyPersonGroups < ActiveRecord::Migration[8.0]
  def up
    create_table :event_key_person_groups do |t|
      t.references :event, null: false, foreign_key: { on_delete: :cascade }
      t.references :event_calendar_tag, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :event_key_person_groups, [:event_id, :name], unique: true
    add_reference :event_guests, :event_key_person_group, foreign_key: true

    say_with_time "Backfilling key person groups" do
      Event.reset_column_information
      EventGuest.reset_column_information
      EventKeyPersonGroup.reset_column_information

      Event.find_each do |event|
        EventKeyPersonGroup.backfill_for_event!(event)
      end
    end
  end

  def down
    remove_reference :event_guests, :event_key_person_group, foreign_key: true
    drop_table :event_key_person_groups
  end
end
