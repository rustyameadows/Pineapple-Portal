class AddSegmentGranularityToCalendarViews < ActiveRecord::Migration[8.0]
  VALID_GRANULARITIES_SQL = "segment_granularity IN ('day', 'month')".freeze

  def change
    add_column :event_calendar_views, :segment_granularity, :string, default: "day", null: false
    add_column :calendar_template_views, :segment_granularity, :string, default: "day", null: false

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE event_calendar_views
          SET segment_granularity = 'month'
          WHERE slug = 'decision-calendar'
        SQL

        execute <<~SQL.squish
          UPDATE calendar_template_views
          SET segment_granularity = 'month'
          WHERE slug = 'decision-calendar'
        SQL
      end
    end

    add_check_constraint :event_calendar_views,
                         VALID_GRANULARITIES_SQL,
                         name: "event_calendar_views_segment_granularity_valid"
    add_check_constraint :calendar_template_views,
                         VALID_GRANULARITIES_SQL,
                         name: "calendar_template_views_segment_granularity_valid"
  end
end
