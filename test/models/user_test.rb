require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "planner contact updates enqueue packet refreshes for linked events" do
    user = users(:one)
    enqueued_event_ids = []

    Documents::Generated::RefreshEventPacketCachesJob.stub :perform_later, ->(event_id) { enqueued_event_ids << event_id } do
      user.update!(phone_number: "555-777-9999")
    end

    assert_equal [events(:one).id], enqueued_event_ids
  end
end
