class AddMemberRoleToEventTeamMembers < ActiveRecord::Migration[8.0]
  def change
    add_column :event_team_members, :member_role, :string, null: false, default: "planner"
    add_index :event_team_members, :member_role
  end
end
