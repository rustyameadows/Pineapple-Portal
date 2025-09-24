class CreateCalendarItemTeamMembers < ActiveRecord::Migration[8.0]
  def change
    create_table :calendar_item_team_members do |t|
      t.references :calendar_item, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :calendar_item_team_members,
              [:calendar_item_id, :user_id],
              unique: true,
              name: "index_calendar_item_team_members_on_item_and_user"
  end
end
