class AddClientVisibleToDocuments < ActiveRecord::Migration[8.0]
  def change
    add_column :documents, :client_visible, :boolean, default: false, null: false
    add_index :documents, :client_visible
  end
end
