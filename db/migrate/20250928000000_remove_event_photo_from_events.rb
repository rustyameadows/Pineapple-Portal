class RemoveEventPhotoFromEvents < ActiveRecord::Migration[7.1]
  def change
    remove_index :events, :event_photo_id if index_exists?(:events, :event_photo_id)
    remove_column :events, :event_photo_id, :bigint, if_exists: true
  end
end
