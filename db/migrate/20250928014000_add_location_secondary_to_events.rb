class AddLocationSecondaryToEvents < ActiveRecord::Migration[7.1]
  def change
    add_column :events, :location_secondary, :string
  end
end
