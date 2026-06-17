class AddTimeAmountDisplayFieldsToCalendarItems < ActiveRecord::Migration[8.0]
  MAJOR_UNITS_SQL = <<~SQL.squish
    CASE
      WHEN %<minutes_column>s IS NOT NULL
        AND %<minutes_column>s <> 0
        AND (%<minutes_column>s %% 43200) = 0 THEN 43200
      WHEN %<minutes_column>s IS NOT NULL
        AND %<minutes_column>s <> 0
        AND (%<minutes_column>s %% 10080) = 0 THEN 10080
      ELSE 1440
    END
  SQL

  UNIT_SQL = <<~SQL.squish
    CASE
      WHEN %<minutes_column>s IS NOT NULL
        AND %<minutes_column>s <> 0
        AND (%<minutes_column>s %% 43200) = 0 THEN 'months'
      WHEN %<minutes_column>s IS NOT NULL
        AND %<minutes_column>s <> 0
        AND (%<minutes_column>s %% 10080) = 0 THEN 'weeks'
      ELSE 'days'
    END
  SQL

  def change
    add_column :calendar_items, :relative_offset_display_value, :integer, default: 0, null: false
    add_column :calendar_items, :relative_offset_display_unit, :string, default: "days", null: false
    add_column :calendar_items, :relative_offset_display_hours, :integer, default: 0, null: false
    add_column :calendar_items, :relative_offset_display_minutes, :integer, default: 0, null: false
    add_column :calendar_items, :duration_display_value, :integer
    add_column :calendar_items, :duration_display_unit, :string
    add_column :calendar_items, :duration_display_hours, :integer
    add_column :calendar_items, :duration_display_minutes, :integer

    reversible do |dir|
      dir.up do
        backfill_relative_offset_display_fields
        backfill_duration_display_fields
      end
    end

    add_check_constraint :calendar_items,
                         "relative_offset_display_unit IN ('days', 'weeks', 'months')",
                         name: "calendar_items_relative_offset_display_unit_valid"
    add_check_constraint :calendar_items,
                         "relative_offset_display_value >= 0",
                         name: "calendar_items_relative_offset_display_value_non_negative"
    add_check_constraint :calendar_items,
                         "relative_offset_display_hours >= 0",
                         name: "calendar_items_relative_offset_display_hours_non_negative"
    add_check_constraint :calendar_items,
                         "relative_offset_display_minutes >= 0",
                         name: "calendar_items_relative_offset_display_minutes_non_negative"
    add_check_constraint :calendar_items,
                         "duration_display_unit IS NULL OR duration_display_unit IN ('days', 'weeks', 'months')",
                         name: "calendar_items_duration_display_unit_valid"
    add_check_constraint :calendar_items,
                         "duration_display_value IS NULL OR duration_display_value >= 0",
                         name: "calendar_items_duration_display_value_non_negative"
    add_check_constraint :calendar_items,
                         "duration_display_hours IS NULL OR duration_display_hours >= 0",
                         name: "calendar_items_duration_display_hours_non_negative"
    add_check_constraint :calendar_items,
                         "duration_display_minutes IS NULL OR duration_display_minutes >= 0",
                         name: "calendar_items_duration_display_minutes_non_negative"
  end

  private

  def backfill_relative_offset_display_fields
    unit_sql = format(UNIT_SQL, minutes_column: "relative_offset_minutes")
    major_unit_sql = format(MAJOR_UNITS_SQL, minutes_column: "relative_offset_minutes")

    execute <<~SQL.squish
      UPDATE calendar_items
      SET relative_offset_display_unit = #{unit_sql},
          relative_offset_display_value = relative_offset_minutes / (#{major_unit_sql}),
          relative_offset_display_hours = (relative_offset_minutes % (#{major_unit_sql})) / 60,
          relative_offset_display_minutes = relative_offset_minutes % 60
    SQL
  end

  def backfill_duration_display_fields
    unit_sql = format(UNIT_SQL, minutes_column: "duration_minutes")
    major_unit_sql = format(MAJOR_UNITS_SQL, minutes_column: "duration_minutes")

    execute <<~SQL.squish
      UPDATE calendar_items
      SET duration_display_unit = #{unit_sql},
          duration_display_value = duration_minutes / (#{major_unit_sql}),
          duration_display_hours = (duration_minutes % (#{major_unit_sql})) / 60,
          duration_display_minutes = duration_minutes % 60
      WHERE duration_minutes IS NOT NULL
    SQL
  end
end
