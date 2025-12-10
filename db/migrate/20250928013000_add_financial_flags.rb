class AddFinancialFlags < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :can_view_financials, :boolean, default: false, null: false
    add_column :event_links, :financial_only, :boolean, default: false, null: false
  end
end
