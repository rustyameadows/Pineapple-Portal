class CreateDocumentBuilds < ActiveRecord::Migration[7.1]
  def change
    create_table :document_builds do |t|
      t.references :document, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.string :build_id, null: false
      t.integer :compiled_page_count
      t.integer :file_size
      t.string :checksum_sha256
      t.datetime :started_at
      t.datetime :finished_at
      t.string :error_message
      t.references :built_by_user, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :document_builds, :build_id, unique: true
  end
end
