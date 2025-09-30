class AddVendorTypeAndSocialToEventVendors < ActiveRecord::Migration[7.1]
  def change
    add_column :event_vendors, :vendor_type, :string
    add_column :event_vendors, :social_handle, :string
  end
end
