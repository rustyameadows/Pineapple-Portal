class CreateEventLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :event_links do |t|
      t.references :event, null: false, foreign_key: true
      t.string :label, null: false
      t.string :url, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :event_links, [:event_id, :position]
  end
end
