class CreateGeneratedPacketSourcesAndPlacements < ActiveRecord::Migration[8.0]
  def change
    create_table :generated_packet_sources do |t|
      t.bigint :event_id, null: false
      t.string :kind, null: false
      t.string :source_category, null: false
      t.string :canonical_key
      t.string :title, null: false, default: ""
      t.jsonb :source_ref, null: false, default: {}
      t.jsonb :spec, null: false, default: {}
      t.string :render_hash
      t.string :cached_pdf_key
      t.datetime :cached_pdf_generated_at
      t.integer :cached_page_count
      t.integer :cached_file_size
      t.string :last_render_error
      t.timestamps
    end

    add_index :generated_packet_sources, :event_id
    add_index :generated_packet_sources, :render_hash
    add_index :generated_packet_sources,
              [:event_id, :canonical_key],
              unique: true,
              where: "canonical_key IS NOT NULL",
              name: "index_generated_packet_sources_on_event_and_canonical"

    create_table :generated_packet_placements do |t|
      t.uuid :document_logical_id, null: false
      t.references :generated_packet_source, null: false, foreign_key: true
      t.integer :position, null: false
      t.timestamps
    end

    add_index :generated_packet_placements,
              [:document_logical_id, :position],
              unique: true,
              name: "index_generated_packet_placements_on_document_and_position"
    add_index :generated_packet_placements, :document_logical_id

    add_check_constraint :generated_packet_placements,
                         "position > 0",
                         name: "generated_packet_placements_position_positive"

    change_table :documents, bulk: true do |t|
      t.integer :packet_schema_version, null: false, default: 1
      t.string :working_storage_uri
      t.string :working_manifest_hash
      t.string :working_checksum_sha256
      t.integer :working_page_count
      t.integer :working_file_size
      t.datetime :working_rendered_at
    end

    add_index :documents, :packet_schema_version
    add_index :documents, :working_manifest_hash
  end
end
