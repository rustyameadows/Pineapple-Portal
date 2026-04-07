class AddKeyPeopleLabelToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :key_people_label, :string
  end
end
