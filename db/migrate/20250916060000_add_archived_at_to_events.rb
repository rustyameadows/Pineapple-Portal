class AddArchivedAtToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :archived_at, :datetime
    add_index :events, :archived_at
  end
end
