class CreateDocumentSegments < ActiveRecord::Migration[7.1]
  def change
    create_table :document_segments do |t|
      t.uuid :document_logical_id, null: false
      t.integer :position, null: false
      t.string :kind, null: false
      t.string :title, null: false, default: ""
      t.jsonb :source_ref, null: false, default: {}
      t.jsonb :spec, null: false, default: {}
      t.timestamps
    end

    add_index :document_segments, [:document_logical_id, :position], unique: true, name: "index_document_segments_on_logical_id_and_position"
    add_index :document_segments, :document_logical_id

    add_check_constraint :document_segments, "position > 0", name: "document_segments_position_positive"
  end
end
