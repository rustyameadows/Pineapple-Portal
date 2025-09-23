class CreateApprovals < ActiveRecord::Migration[8.0]
  def change
    create_table :approvals do |t|
      t.references :event, null: false, foreign_key: true
      t.string :title, null: false
      t.text :summary
      t.text :instructions
      t.boolean :client_visible, null: false, default: false
      t.string :status, null: false, default: "pending"
      t.string :client_name
      t.text :client_note
      t.datetime :acknowledged_at

      t.timestamps
    end

    add_index :approvals, [:event_id, :status]
    add_index :approvals, [:event_id, :client_visible]
  end
end
