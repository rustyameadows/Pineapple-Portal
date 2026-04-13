class AddWorkingStatusToDocuments < ActiveRecord::Migration[8.0]
  def change
    add_column :documents, :working_status, :string, null: false, default: "missing"
    add_column :documents, :working_refresh_requested_at, :datetime
    add_column :documents, :working_refresh_started_at, :datetime
    add_column :documents, :working_refresh_error, :text

    add_index :documents, :working_status
  end
end
