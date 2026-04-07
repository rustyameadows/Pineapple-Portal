class AddEventMetadataFieldsToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :guest_count, :string
    add_column :events, :attire, :string
    add_column :events, :style, :string
    add_column :events, :color_palette, :string
    add_column :events, :social_media_policy, :text
    add_column :events, :parking_details, :text
    add_column :events, :getting_ready_details, :text
  end
end
