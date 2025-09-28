class CreateGlobalAssets < ActiveRecord::Migration[7.1]
  def change
    create_table :global_assets do |t|
      t.string :storage_uri, null: false
      t.string :filename, null: false
      t.string :content_type, null: false
      t.bigint :size_bytes
      t.string :checksum
      t.string :label
      t.references :uploaded_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :global_assets, :storage_uri, unique: true
  end
end
