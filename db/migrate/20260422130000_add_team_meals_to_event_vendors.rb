class AddTeamMealsToEventVendors < ActiveRecord::Migration[7.1]
  def change
    add_column :event_vendors, :team_meals, :text
  end
end
