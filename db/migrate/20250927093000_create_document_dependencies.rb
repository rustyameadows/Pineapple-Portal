class CreateDocumentDependencies < ActiveRecord::Migration[7.1]
  def change
    create_table :document_dependencies do |t|
      t.uuid :document_logical_id, null: false
      t.bigint :segment_id, null: false
      t.string :entity_type, null: false
      t.bigint :entity_id, null: false
      t.timestamps
    end

    add_index :document_dependencies, [:entity_type, :entity_id], name: "index_document_dependencies_on_entity"
    add_index :document_dependencies, :document_logical_id

    add_foreign_key :document_dependencies, :document_segments, column: :segment_id, on_delete: :cascade
  end
end
