class AddContactsToGlobalVendorsAndVenues < ActiveRecord::Migration[8.0]
  def change
    add_column :global_vendors, :contacts_jsonb, :jsonb, null: false, default: []
    add_column :global_venues, :contacts_jsonb, :jsonb, null: false, default: []

    add_check_constraint :global_vendors,
                         "jsonb_typeof(contacts_jsonb) = 'array'",
                         name: "global_vendors_contacts_jsonb_array"

    add_check_constraint :global_venues,
                         "jsonb_typeof(contacts_jsonb) = 'array'",
                         name: "global_venues_contacts_jsonb_array"
  end
end
