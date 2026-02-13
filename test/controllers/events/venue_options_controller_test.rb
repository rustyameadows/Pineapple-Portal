require "test_helper"

module Events
  class VenueOptionsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @event = events(:one)
      log_in_as(users(:two))
    end

    test "returns active event venues before non-active matches" do
      active_global = GlobalVenue.create!(name: "Active Venue")
      inactive_global = GlobalVenue.create!(name: "Inactive Venue")

      @event.event_venues.create!(name: active_global.name, global_venue: active_global, client_visible: true)
      events(:two).event_venues.create!(name: inactive_global.name, global_venue: inactive_global, client_visible: true)

      get event_venue_options_url(@event), params: { q: "venue" }, as: :json

      assert_response :success
      body = JSON.parse(response.body)
      names = body.fetch("options").map { |item| item.fetch("name") }
      assert_equal "Active Venue", names.first
    end
  end
end
