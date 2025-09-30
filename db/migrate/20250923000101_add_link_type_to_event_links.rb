class AddLinkTypeToEventLinks < ActiveRecord::Migration[8.0]
  def change
    add_column :event_links, :link_type, :string, null: false, default: "quick"

    add_index :event_links, [:event_id, :link_type]
  end
end
