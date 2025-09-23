class CreateEventCalendars < ActiveRecord::Migration[8.0]
  def change
    create_table :event_calendars do |t|
      t.references :event, null: false, foreign_key: true
      t.string :name, null: false
      t.string :slug, null: false
      t.string :description
      t.string :timezone, null: false, default: "UTC"
      t.string :kind, null: false, default: "master"
      t.boolean :client_visible, null: false, default: false
      t.bigint :template_source_id
      t.integer :position, null: false, default: 0
      t.integer :template_version
      t.timestamps
    end

    add_index :event_calendars, [:event_id, :slug], unique: true
    add_index :event_calendars, :template_source_id
    add_index :event_calendars, :kind
    add_index :event_calendars,
              :event_id,
              unique: true,
              where: "kind = 'master'",
              name: "index_event_calendars_on_event_id_and_master"

    add_check_constraint :event_calendars,
                         "kind IN ('master', 'derived')",
                         name: "event_calendars_kind_check"

    create_table :calendar_items do |t|
      t.references :event_calendar, null: false, foreign_key: { on_delete: :cascade }
      t.string :title, null: false
      t.text :notes
      t.integer :duration_minutes
      t.datetime :starts_at
      t.references :relative_anchor, foreign_key: { to_table: :calendar_items, on_delete: :nullify }
      t.integer :relative_offset_minutes, default: 0, null: false
      t.boolean :relative_before, default: false, null: false
      t.boolean :locked, default: false, null: false
      t.integer :position, null: false, default: 0
      t.string :tag_summary, array: true, default: [], null: false
      t.timestamps
    end

    add_index :calendar_items, [:event_calendar_id, :position], name: "index_calendar_items_on_calendar_and_position"
    add_index :calendar_items, :starts_at

    add_check_constraint :calendar_items,
                         "relative_offset_minutes IS NOT NULL",
                         name: "calendar_items_relative_offset_present"

    add_check_constraint :calendar_items,
                         "duration_minutes IS NULL OR duration_minutes >= 0",
                         name: "calendar_items_duration_non_negative"

    create_table :event_calendar_tags do |t|
      t.references :event_calendar, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.string :color_token
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :event_calendar_tags, [:event_calendar_id, :name], unique: true, name: "index_event_calendar_tags_on_calendar_and_name"

    create_table :calendar_item_tags do |t|
      t.references :calendar_item, null: false, foreign_key: { on_delete: :cascade }
      t.references :event_calendar_tag, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end

    add_index :calendar_item_tags,
              [:calendar_item_id, :event_calendar_tag_id],
              unique: true,
              name: "index_calendar_item_tags_on_item_and_tag"

    create_table :event_calendar_views do |t|
      t.references :event_calendar, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.string :slug, null: false
      t.string :description
      t.jsonb :tag_filter, null: false, default: []
      t.boolean :hide_locked, null: false, default: false
      t.boolean :client_visible, null: false, default: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :event_calendar_views,
              [:event_calendar_id, :slug],
              unique: true,
              name: "index_event_calendar_views_on_calendar_and_slug"

    add_check_constraint :event_calendar_views,
                         "jsonb_typeof(tag_filter) = 'array'",
                         name: "event_calendar_views_tag_filter_array"
  end
end
