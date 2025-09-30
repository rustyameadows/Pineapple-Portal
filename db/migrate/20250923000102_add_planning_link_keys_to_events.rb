class AddPlanningLinkKeysToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :planning_link_keys, :jsonb, null: false, default: []

    add_check_constraint :events, "jsonb_typeof(planning_link_keys) = 'array'", name: "events_planning_link_keys_array"
  end
end
