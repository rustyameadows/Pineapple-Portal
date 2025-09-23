class AddClientVisibleToQuestionnaires < ActiveRecord::Migration[8.0]
  def change
    add_column :questionnaires, :client_visible, :boolean, default: false, null: false
    add_index :questionnaires, :client_visible
  end
end
