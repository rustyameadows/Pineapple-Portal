class AddRoleTitlePhoneToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :role, :string, null: false, default: "planner"
    add_column :users, :title, :string
    add_column :users, :phone_number, :string

    add_index :users, :role
  end
end
