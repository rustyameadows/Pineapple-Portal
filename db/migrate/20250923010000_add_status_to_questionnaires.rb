class AddStatusToQuestionnaires < ActiveRecord::Migration[8.0]
  def change
    add_column :questionnaires, :status, :string, null: false, default: "in_progress"
    add_index :questionnaires, :status
  end
end
