class AddLeadPlannerAndPositionToEventTeamMembers < ActiveRecord::Migration[8.0]
  def change
    add_column :event_team_members, :lead_planner, :boolean, null: false, default: false
    add_column :event_team_members, :position, :integer, null: false, default: 0

    add_index :event_team_members, :lead_planner
    add_index :event_team_members, [:event_id, :position]
  end
end
