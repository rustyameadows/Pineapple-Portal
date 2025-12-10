class AddNotesFieldsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :general_notes, :text
    add_column :users, :dietary_restrictions, :text
  end
end
