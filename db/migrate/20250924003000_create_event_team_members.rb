class CreateEventTeamMembers < ActiveRecord::Migration[8.0]
  def change
    create_table :event_team_members do |t|
      t.references :event, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.boolean :client_visible, null: false, default: false

      t.timestamps
    end

    add_index :event_team_members, [:event_id, :user_id], unique: true
    add_index :event_team_members, :client_visible
  end
end
