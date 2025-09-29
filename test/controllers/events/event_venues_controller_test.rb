require "test_helper"

module Events
  class EventVenuesControllerTest < ActionDispatch::IntegrationTest
    setup do
      @event = events(:one)
      log_in_as(users(:two))
    end

    test "creates venue" do
      assert_difference("EventVenue.count") do
        post event_event_venues_url(@event), params: {
          event_venue: {
            name: "Skyline Loft",
            client_visible: "1",
            contacts_attributes: {
              "0" => {
                name: "Loft Contact",
                phone: "111-111-1111"
              }
            }
          }
        }
      end

      assert_redirected_to locations_event_settings_url(@event)
      venue = EventVenue.find_by(name: "Skyline Loft")
      assert_equal "111-111-1111", venue.contacts.first["phone"]
    end

    test "updates venue visibility" do
      venue = event_venues(:backup_space)

      patch event_event_venue_url(@event, venue), params: {
        event_venue: { client_visible: "1" }
      }

      assert_redirected_to locations_event_settings_url(@event)
      assert venue.reload.client_visible?
    end

    test "move down swaps ordering" do
      top = event_venues(:main_hall)
      bottom = event_venues(:backup_space)
      assert top.position < bottom.position

      patch move_down_event_event_venue_url(@event, top)

      assert_redirected_to locations_event_settings_url(@event)
      top.reload
      bottom.reload
      assert top.position > bottom.position
    end

    test "destroys venue" do
      venue = event_venues(:backup_space)

      assert_difference("EventVenue.count", -1) do
        delete event_event_venue_url(@event, venue)
      end

      assert_redirected_to locations_event_settings_url(@event)
    end
  end
end
