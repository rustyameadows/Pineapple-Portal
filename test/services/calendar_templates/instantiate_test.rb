require "test_helper"

module CalendarTemplates
  class InstantiateTest < ActiveSupport::TestCase
    setup do
      @event = events(:two)
      @template = CalendarTemplate.create!(
        name: "Weekend Run of Show",
        slug: "weekend-run-of-show",
        default_timezone: "UTC",
        variable_definitions: {}
      )

      @tag = @template.calendar_template_tags.create!(name: "Vendor", position: 0)

      @setup = @template.calendar_template_items.create!(
        title: "Setup",
        default_offset_minutes: 0,
        position: 0
      )

      @ceremony = @template.calendar_template_items.create!(
        title: "Ceremony",
        default_offset_minutes: 120,
        default_before: false,
        relative_anchor_template_item: @setup,
        position: 1
      )

      CalendarTemplateItemTag.create!(
        calendar_template_item: @ceremony,
        calendar_template_tag: @tag
      )

      @template.calendar_template_views.create!(
        name: "Vendors",
        slug: "vendors",
        tag_filter: [@tag.id],
        hide_locked: false,
        client_visible_by_default: true,
        position: 0
      )
    end

    test "instantiates a template for an event" do
      result = Instantiate.new(template: @template, event: @event, calendar_name: "Weekend").call

      calendar = result.calendar
      assert_equal @event, calendar.event
      assert_equal "Weekend", calendar.name
      assert_equal @template, calendar.template_source
      assert_equal @template.version, calendar.template_version

      assert_equal 2, calendar.calendar_items.count
      assert_equal 1, calendar.event_calendar_tags.count
      assert_equal 1, calendar.event_calendar_views.count

      ceremony = calendar.calendar_items.find_by(title: "Ceremony")
      setup = calendar.calendar_items.find_by(title: "Setup")

      assert_equal setup, ceremony.relative_anchor
      assert_equal ["Vendor"], ceremony.event_calendar_tags.pluck(:name)
    end
  end
end
