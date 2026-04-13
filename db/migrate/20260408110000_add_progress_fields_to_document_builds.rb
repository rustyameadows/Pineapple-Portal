class AddProgressFieldsToDocumentBuilds < ActiveRecord::Migration[8.0]
  def change
    add_column :document_builds, :progress_stage, :string
    add_column :document_builds, :progress_message, :string
    add_column :document_builds, :progress_current, :integer
    add_column :document_builds, :progress_total, :integer
    add_column :document_builds, :last_progress_at, :datetime
  end
end
