require "openai"

module RosAgent
  class OpenaiClient
    def initialize(api_key: ENV.fetch("OPENAI_API_KEY"))
      @client = OpenAI::Client.new(api_key: api_key)
    end

    def responses_create(**payload)
      client.responses.create(payload)
    end

    def files_create(**payload)
      client.files.create(payload)
    end

    private

    attr_reader :client
  end
end
