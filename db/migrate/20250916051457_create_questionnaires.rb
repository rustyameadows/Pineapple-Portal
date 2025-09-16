class CreateQuestionnaires < ActiveRecord::Migration[8.0]
  def change
    create_table :questionnaires do |t|
      t.references :event, null: false, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.boolean :is_template, null: false, default: false
      t.bigint :template_source_id

      t.timestamps
    end

    add_foreign_key :questionnaires, :questionnaires, column: :template_source_id
    add_index :questionnaires, :is_template
    add_index :questionnaires, :template_source_id

    reversible do |dir|
      dir.up do
        execute <<~SQL
          CREATE UNIQUE INDEX index_questionnaires_on_event_id_and_template_source_id
          ON questionnaires (event_id, template_source_id)
          WHERE template_source_id IS NOT NULL;
        SQL
      end

      dir.down do
        execute <<~SQL
          DROP INDEX IF EXISTS index_questionnaires_on_event_id_and_template_source_id;
        SQL
      end
    end
  end
end
