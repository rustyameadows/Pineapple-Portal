class CreateAttachments < ActiveRecord::Migration[8.0]
  def change
    create_table :attachments do |t|
      t.references :entity, polymorphic: true, null: false
      t.references :document, null: true, foreign_key: true
      t.uuid :document_logical_id
      t.string :context, null: false, default: "other"
      t.integer :position, null: false, default: 1
      t.text :notes

      t.timestamps
    end

    add_index :attachments, :document_logical_id
    add_index :attachments, [:entity_type, :entity_id, :context, :position], unique: true, name: "index_attachments_on_entity_scope"

    add_check_constraint :attachments,
                          "(document_id IS NOT NULL AND document_logical_id IS NULL) OR (document_id IS NULL AND document_logical_id IS NOT NULL)",
                          name: "attachments_exactly_one_document_reference"
    add_check_constraint :attachments,
                          "context IN ('prompt', 'help_text', 'answer', 'other')",
                          name: "attachments_context_valid"
  end
end
