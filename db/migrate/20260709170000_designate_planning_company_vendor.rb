class DesignatePlanningCompanyVendor < ActiveRecord::Migration[8.0]
  PLANNING_COMPANY_NAME = "pineapple productions".freeze
  PLANNING_COMPANY_ROLE = "planning_company".freeze

  class GlobalVendorRecord < ActiveRecord::Base
    self.table_name = "global_vendors"
  end

  class EventRecord < ActiveRecord::Base
    self.table_name = "events"
  end

  class EventVendorRecord < ActiveRecord::Base
    self.table_name = "event_vendors"
  end

  class EventVendorBackfill
    def initialize(global_vendor)
      @global_vendor = global_vendor
    end

    def call
      EventRecord.order(:id).find_each do |event|
        next if EventVendorRecord.exists?(event_id: event.id, global_vendor_id: global_vendor.id)

        EventVendorRecord.create!(
          event_id: event.id,
          global_vendor_id: global_vendor.id,
          name: global_vendor.name,
          vendor_type: global_vendor.default_vendor_type,
          social_handle: global_vendor.default_social_handle,
          client_visible: false,
          position: next_position(event.id),
          contacts_jsonb: [],
          created_at: Time.current,
          updated_at: Time.current
        )
      end

      verify!
    end

    private

    attr_reader :global_vendor

    def next_position(event_id)
      EventVendorRecord.where(event_id:).maximum(:position).to_i + 1
    end

    def verify!
      missing_count = EventRecord
                      .where.not(
                        id: EventVendorRecord.where(global_vendor_id: global_vendor.id).select(:event_id)
                      )
                      .count
      return if missing_count.zero?

      raise ActiveRecord::MigrationError,
            "Failed to associate the planning company with #{missing_count} events"
    end
  end

  def up
    add_column :global_vendors, :system_role, :string
    add_check_constraint :global_vendors,
                         "system_role IS NULL OR system_role = '#{PLANNING_COMPANY_ROLE}'",
                         name: "global_vendors_system_role_known"
    add_index :global_vendors,
              :system_role,
              unique: true,
              where: "system_role IS NOT NULL",
              name: "index_global_vendors_on_unique_system_role"

    GlobalVendorRecord.reset_column_information
    planning_company = GlobalVendorRecord.find_by(normalized_name: PLANNING_COMPANY_NAME)
    unless planning_company
      raise ActiveRecord::MigrationError,
            "A global vendor normalized as '#{PLANNING_COMPANY_NAME}' is required"
    end

    planning_company.update!(system_role: PLANNING_COMPANY_ROLE)
    EventVendorBackfill.new(planning_company).call
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          "Planning-company event links may be referenced by vendor assignments"
  end
end
