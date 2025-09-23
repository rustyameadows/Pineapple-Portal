class CreatePayments < ActiveRecord::Migration[8.0]
  def change
    create_table :payments do |t|
      t.references :event, null: false, foreign_key: true
      t.string :title, null: false
      t.decimal :amount, precision: 12, scale: 2, null: false, default: 0
      t.date :due_on
      t.text :description
      t.boolean :client_visible, null: false, default: false
      t.string :status, null: false, default: "pending"
      t.datetime :paid_at
      t.datetime :paid_by_client_at
      t.text :client_note

      t.timestamps
    end

    add_index :payments, [:event_id, :due_on]
    add_index :payments, [:event_id, :status]
  end
end
