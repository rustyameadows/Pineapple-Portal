class CreateDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :documents do |t|
      t.references :event, null: false, foreign_key: true
      t.string :title, null: false
      t.string :storage_uri, null: false
      t.string :checksum, null: false
      t.bigint :size_bytes, null: false
      t.uuid :logical_id, null: false
      t.integer :version, null: false
      t.boolean :is_latest, null: false, default: true
      t.string :content_type, null: false

      t.timestamps
    end

    add_index :documents, [:logical_id, :version], unique: true
    add_check_constraint :documents, "size_bytes > 0", name: "documents_size_positive"
    add_check_constraint :documents, "version > 0", name: "documents_version_positive"

    reversible do |dir|
      dir.up do
        execute <<~SQL
          CREATE UNIQUE INDEX index_documents_on_logical_id_latest
          ON documents (logical_id)
          WHERE is_latest = true;
        SQL
      end

      dir.down do
        execute <<~SQL
          DROP INDEX IF EXISTS index_documents_on_logical_id_latest;
        SQL
      end
    end
  end
end
