class AddFinancialPortalVisibleToDocuments < ActiveRecord::Migration[7.1]
  def change
    add_column :documents, :financial_portal_visible, :boolean, default: false, null: false
  end
end
