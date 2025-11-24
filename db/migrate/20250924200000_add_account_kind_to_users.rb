class AddAccountKindToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :account_kind, :string, null: false, default: "account"
    add_index :users, :account_kind
  end
end
