class CreateQuestions < ActiveRecord::Migration[8.0]
  def change
    create_table :questions do |t|
      t.references :questionnaire, null: false, foreign_key: true
      t.references :event, null: false, foreign_key: true
      t.text :prompt, null: false
      t.text :help_text
      t.string :response_type, null: false, default: "text"
      t.integer :position, null: false, default: 1
      t.text :answer_value
      t.jsonb :answer_raw, default: {}
      t.datetime :answered_at

      t.timestamps
    end

    add_index :questions, [:questionnaire_id, :position]
  end
end
