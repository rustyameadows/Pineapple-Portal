class AddPacketsPortalVisibleToDocuments < ActiveRecord::Migration[8.0]
  def change
    add_column :documents, :packets_portal_visible, :boolean, null: false, default: false
    add_index :documents, :packets_portal_visible
  end
end
