class AddEventPhotoToEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :events, :event_photo_id, :bigint
    add_index :events, :event_photo_id
  end
end
