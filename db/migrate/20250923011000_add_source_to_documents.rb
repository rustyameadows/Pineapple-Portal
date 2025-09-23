class AddSourceToDocuments < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    add_column :documents, :source, :string, null: false, default: "staff_upload"
    add_index :documents, :source, algorithm: :concurrently
  end

  def down
    remove_index :documents, :source
    remove_column :documents, :source
  end
end
