class AddPineappleTeamMealsToEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :events, :pineapple_team_meals, :text
  end
end
