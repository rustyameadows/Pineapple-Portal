class AddTimeCaptionToCalendarItems < ActiveRecord::Migration[8.0]
  def change
    add_column :calendar_items, :time_caption, :string
  end
end
