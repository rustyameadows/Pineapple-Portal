class AddUnifiedFieldsToDocumentBuilds < ActiveRecord::Migration[8.0]
  def change
    add_column :document_builds, :build_kind, :string, null: false, default: "snapshot"
    add_column :document_builds, :storage_uri, :string
    add_column :document_builds, :manifest_hash, :string
    add_column :document_builds, :page_numbers, :boolean, null: false, default: true

    add_index :document_builds, :build_kind
    add_index :document_builds,
              [:document_id, :build_kind, :created_at],
              name: "index_document_builds_on_document_id_build_kind_created_at"
  end
end
