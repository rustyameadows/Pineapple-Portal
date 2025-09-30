class CreateEventVendors < ActiveRecord::Migration[7.1]
  def change
    create_table :event_vendors do |t|
      t.references :event, null: false, foreign_key: true
      t.string :name, null: false
      t.jsonb :contacts_jsonb, null: false, default: []
      t.integer :position, null: false, default: 0
      t.boolean :client_visible, null: false, default: true
      t.timestamps
    end

    add_index :event_vendors, %i[event_id position]

    add_check_constraint :event_vendors,
                         "jsonb_typeof(contacts_jsonb) = 'array'",
                         name: "event_vendors_contacts_jsonb_array"

    execute <<~SQL.squish
      CREATE UNIQUE INDEX index_event_vendors_on_event_id_and_lower_name
      ON event_vendors (event_id, lower(name));
    SQL
  end
end
