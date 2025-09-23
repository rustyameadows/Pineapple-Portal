class CreateQuestionnaireSections < ActiveRecord::Migration[8.0]
  class MigrationQuestionnaire < ApplicationRecord
    self.table_name = "questionnaires"
    has_many :questions, class_name: "CreateQuestionnaireSections::MigrationQuestion", foreign_key: :questionnaire_id
  end

  class MigrationQuestion < ApplicationRecord
    self.table_name = "questions"
  end

  class MigrationSection < ApplicationRecord
    self.table_name = "questionnaire_sections"
  end

  def up
    create_table :questionnaire_sections do |t|
      t.references :questionnaire, null: false, foreign_key: true
      t.string :title, null: false
      t.text :helper_text
      t.integer :position, null: false, default: 1
      t.timestamps
    end

    add_index :questionnaire_sections, [:questionnaire_id, :position]

    add_reference :questions, :questionnaire_section, foreign_key: { to_table: :questionnaire_sections }

    MigrationQuestion.reset_column_information

    say_with_time "Backfilling questionnaire sections" do
      MigrationQuestionnaire.find_each do |questionnaire|
        section = MigrationSection.create!(
          questionnaire_id: questionnaire.id,
          title: questionnaire.title.presence || "Section 1",
          helper_text: nil,
          position: 1
        )

        questionnaire.questions.order(:position).update_all(questionnaire_section_id: section.id)
      end
    end

    change_column_null :questions, :questionnaire_section_id, false
  end

  def down
    remove_reference :questions, :questionnaire_section, foreign_key: true
    drop_table :questionnaire_sections
  end
end
