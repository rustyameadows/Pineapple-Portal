class CreateCalendarTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :calendar_templates do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :description
      t.string :default_timezone, null: false, default: "UTC"
      t.string :category
      t.jsonb :variable_definitions, null: false, default: {}
      t.integer :version, null: false, default: 1
      t.boolean :archived, null: false, default: false
      t.timestamps
    end

    add_index :calendar_templates, :slug, unique: true
    add_check_constraint :calendar_templates,
                         "jsonb_typeof(variable_definitions) = 'object'",
                         name: "calendar_templates_variable_definitions_object"

    create_table :calendar_template_tags do |t|
      t.references :calendar_template, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.string :color_token
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :calendar_template_tags,
              [:calendar_template_id, :name],
              unique: true,
              name: "index_calendar_template_tags_on_template_and_name"

    create_table :calendar_template_items do |t|
      t.references :calendar_template, null: false, foreign_key: { on_delete: :cascade }
      t.string :title, null: false
      t.text :notes
      t.integer :duration_minutes
      t.integer :default_offset_minutes, null: false, default: 0
      t.boolean :default_before, null: false, default: false
      t.boolean :locked_by_default, null: false, default: false
      t.bigint :relative_anchor_template_item_id
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :calendar_template_items,
              [:calendar_template_id, :position],
              name: "index_calendar_template_items_on_template_and_position"

    add_foreign_key :calendar_template_items,
                    :calendar_template_items,
                    column: :relative_anchor_template_item_id,
                    on_delete: :nullify

    add_check_constraint :calendar_template_items,
                         "duration_minutes IS NULL OR duration_minutes >= 0",
                         name: "calendar_template_items_duration_non_negative"

    create_table :calendar_template_item_tags do |t|
      t.references :calendar_template_item, null: false, foreign_key: { on_delete: :cascade }
      t.references :calendar_template_tag, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end

    add_index :calendar_template_item_tags,
              [:calendar_template_item_id, :calendar_template_tag_id],
              unique: true,
              name: "index_calendar_template_item_tags_on_item_and_tag"

    create_table :calendar_template_views do |t|
      t.references :calendar_template, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.string :slug, null: false
      t.string :description
      t.jsonb :tag_filter, null: false, default: []
      t.boolean :hide_locked, null: false, default: false
      t.boolean :client_visible_by_default, null: false, default: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :calendar_template_views,
              [:calendar_template_id, :slug],
              unique: true,
              name: "index_calendar_template_views_on_template_and_slug"

    add_check_constraint :calendar_template_views,
                         "jsonb_typeof(tag_filter) = 'array'",
                         name: "calendar_template_views_tag_filter_array"

    add_foreign_key :event_calendars,
                    :calendar_templates,
                    column: :template_source_id,
                    on_delete: :nullify
  end
end
