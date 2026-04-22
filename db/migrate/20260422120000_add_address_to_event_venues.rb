class AddAddressToEventVenues < ActiveRecord::Migration[8.0]
  def change
    add_column :event_venues, :address, :text
  end
end
