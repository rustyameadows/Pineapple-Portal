require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "planner contact updates no longer enqueue the broad event refresh job" do
    user = users(:one)
    enqueued_event_ids = []

    Documents::Generated::RefreshEventPacketCachesJob.stub :perform_later, ->(event_id) { enqueued_event_ids << event_id } do
      user.update!(phone_number: "555-777-9999")
    end

    assert_equal [], enqueued_event_ids
  end
end
