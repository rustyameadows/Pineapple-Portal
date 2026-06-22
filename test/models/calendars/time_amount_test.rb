require "test_helper"

module Calendars
  class TimeAmountTest < ActiveSupport::TestCase
    test "normalizes decimal hours into hours and minutes" do
      amount = TimeAmount.from_display(value: "0", unit: "days", hours: "6.5", minutes: "0")

      assert_equal 390, amount.total_minutes
      assert_equal 0, amount.value
      assert_equal "days", amount.unit
      assert_equal 6, amount.hours
      assert_equal 30, amount.minutes
      assert_equal "6 hr 30 min", amount.label
    end

    test "normalizes overflow minutes into hours and minutes" do
      amount = TimeAmount.from_display(value: "0", unit: "days", hours: "1", minutes: "90")

      assert_equal 150, amount.total_minutes
      assert_equal 0, amount.value
      assert_equal "days", amount.unit
      assert_equal 2, amount.hours
      assert_equal 30, amount.minutes
      assert_equal "2 hr 30 min", amount.label
    end

    test "keeps exact weeks as weeks" do
      amount = TimeAmount.from_display(value: "2", unit: "weeks", hours: "0", minutes: "0")

      assert_equal 20_160, amount.total_minutes
      assert_equal 2, amount.value
      assert_equal "weeks", amount.unit
      assert_equal 0, amount.hours
      assert_equal 0, amount.minutes
      assert_equal "2 weeks", amount.label
    end

    test "keeps month behavior as thirty days" do
      amount = TimeAmount.from_display(value: "1", unit: "months", hours: "0", minutes: "0")

      assert_equal 43_200, amount.total_minutes
      assert_equal 1, amount.value
      assert_equal "months", amount.unit
      assert_equal "1 month", amount.label
    end

    test "derives friendly display fields from canonical minutes" do
      amount = TimeAmount.from_minutes(390)

      assert_equal 390, amount.total_minutes
      assert_equal 0, amount.value
      assert_equal "days", amount.unit
      assert_equal 6, amount.hours
      assert_equal 30, amount.minutes
      assert_equal "6 hr 30 min", amount.label
    end
  end
end
