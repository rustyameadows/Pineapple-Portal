class AddFinancialPaymentsEnabledToEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :events, :financial_payments_enabled, :boolean, default: false, null: false
  end
end
