require "test_helper"

module RosAgent
  class OpenaiClientTest < ActiveSupport::TestCase
    test "delegates responses and files calls to the sdk client" do
      responses_api = Minitest::Mock.new
      files_api = Minitest::Mock.new
      sdk_client = Struct.new(:responses, :files).new(responses_api, files_api)
      built_clients = []
      file = StringIO.new("hello")

      responses_api.expect(:create, { "id" => "resp_123" }, [{ model: "gpt-5.5", input: [] }])
      files_api.expect(:create, { "id" => "file_123" }, [{ file: file, purpose: "assistants" }])

      OpenAI::Client.stub :new, ->(api_key:) {
        built_clients << api_key
        sdk_client
      } do
        client = OpenaiClient.new(api_key: "test-key")

        assert_equal({ "id" => "resp_123" }, client.responses_create(model: "gpt-5.5", input: []))
        assert_equal({ "id" => "file_123" }, client.files_create(file: file, purpose: "assistants"))
      end

      assert_equal ["test-key"], built_clients
      responses_api.verify
      files_api.verify
    end

    test "requires OPENAI_API_KEY when api_key is not provided" do
      existing_value = ENV.delete("OPENAI_API_KEY")

      error = assert_raises(KeyError) do
        OpenaiClient.new
      end

      assert_match "OPENAI_API_KEY", error.message
    ensure
      ENV["OPENAI_API_KEY"] = existing_value if existing_value
    end
  end
end
