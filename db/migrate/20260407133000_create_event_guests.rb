class CreateEventGuests < ActiveRecord::Migration[8.0]
  def change
    create_table :event_guests do |t|
      t.references :event, null: false, foreign_key: true
      t.string :kind, null: false, default: "key_person"
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :relationship, null: false
      t.boolean :vip, null: false, default: false
      t.string :group_name, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :event_guests, [:event_id, :kind]
    add_index :event_guests, [:event_id, :position]
  end
end
