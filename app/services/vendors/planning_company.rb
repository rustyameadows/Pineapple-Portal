module Vendors
  module PlanningCompany
    SYSTEM_ROLE = GlobalVendor::SYSTEM_ROLES.fetch(:planning_company)

    module_function

    def event_vendor?(event_vendor)
      event_vendor.global_vendor&.system_role == SYSTEM_ROLE
    end

    def event_vendor_for(event)
      event.event_vendors
           .joins(:global_vendor)
           .find_by(global_vendors: { system_role: SYSTEM_ROLE })
    end

    def global_vendor_for(event)
      event_vendor_for(event)&.global_vendor || GlobalVendor.planning_company
    end

    def excluding(relation)
      relation
        .left_joins(:global_vendor)
        .where(
          "global_vendors.system_role IS DISTINCT FROM ?",
          SYSTEM_ROLE
        )
    end
  end
end
