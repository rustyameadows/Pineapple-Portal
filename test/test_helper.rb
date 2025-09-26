ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

module AuthenticationHelpers
  def log_in_as(user, password: "password123")
    post login_url, params: { email: user.email, password: password }
  end

  def log_in_client_portal(user, password: "password123")
    post client_login_url, params: { email: user.email, password: password }
  end
end

class ActionDispatch::IntegrationTest
  include AuthenticationHelpers
end
