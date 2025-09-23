class SetEventTeamMembersVisible < ActiveRecord::Migration[8.0]
  def change
    change_column_default :event_team_members, :client_visible, from: false, to: true
  end
end
