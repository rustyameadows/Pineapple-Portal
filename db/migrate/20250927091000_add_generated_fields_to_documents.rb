class AddGeneratedFieldsToDocuments < ActiveRecord::Migration[7.1]
  def change
    change_table :documents, bulk: true do |t|
      t.string :doc_kind, null: false, default: "uploaded"
      t.boolean :is_template, null: false, default: false
      t.uuid :template_source_logical_id
      t.bigint :built_by_user_id
      t.uuid :build_id
      t.string :manifest_hash
      t.string :checksum_sha256
    end

    add_index :documents, :doc_kind
    add_index :documents, :template_source_logical_id
    add_index :documents, :build_id
    add_foreign_key :documents, :users, column: :built_by_user_id
  end
end
