class AddRelativeToAnchorEndToCalendarItems < ActiveRecord::Migration[8.0]
  def change
    add_column :calendar_items, :relative_to_anchor_end, :boolean, default: false, null: false
  end
end
