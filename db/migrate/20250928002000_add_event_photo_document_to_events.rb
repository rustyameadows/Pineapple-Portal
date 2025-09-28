class AddEventPhotoDocumentToEvents < ActiveRecord::Migration[7.1]
  def change
    add_reference :events, :event_photo_document, foreign_key: { to_table: :documents }, index: true
  end
end
