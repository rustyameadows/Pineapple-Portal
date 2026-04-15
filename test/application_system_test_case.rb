require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  private

  def login_as_planner(user = users(:one), password: "password123")
    visit root_path
    return if page.has_text?("Your Active Events", wait: 2)

    2.times do
      visit login_path
      return if page.has_text?("Your Active Events", wait: 2)

      next unless page.has_field?("Email", wait: 2)

      fill_in "Email", with: user.email
      fill_in "Password", with: password
      click_button "Log In"

      return if page.has_text?("Your Active Events", wait: 5)
    end

    assert_text "Your Active Events"
  end
end
