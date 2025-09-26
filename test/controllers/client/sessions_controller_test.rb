require "test_helper"

module Client
  class SessionsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @client = users(:client_contact)
    end

    test "logs out via delete" do
      log_in_client_portal(@client)

      delete client_logout_url
      assert_redirected_to client_login_url
      assert_nil session[:client_user_id]
    end

    test "logs out via get fallback" do
      log_in_client_portal(@client)

      get client_logout_url
      assert_redirected_to client_login_url
      assert_nil session[:client_user_id]
    end
  end
end
