require "test_helper"

class EventTest < ActiveSupport::TestCase
  test "requires a name" do
    event = Event.new
    assert_not event.valid?
    assert_includes event.errors[:name], "can't be blank"
  end
end
