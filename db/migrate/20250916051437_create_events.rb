class CreateEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :events do |t|
      t.string :name, null: false
      t.date :starts_on
      t.date :ends_on
      t.string :location

      t.timestamps
    end

    add_index :events, :name
  end
end
