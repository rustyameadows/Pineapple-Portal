module RosAgent
  class TraceRecorder
    SECRET_KEYS = %w[api_key OPENAI_API_KEY Authorization authorization].freeze
    BEARER_PATTERN = /Bearer\s+sk-[A-Za-z0-9_\-]+/.freeze
    SECRET_PATTERN = /sk-[A-Za-z0-9_\-]+/.freeze

    def initialize(task:, purpose:, model:, request_payload:, reasoning_effort: nil, schema_name: nil, schema_version: nil, started_at: Time.current)
      @task = task
      @purpose = purpose
      @model = model
      @reasoning_effort = reasoning_effort
      @schema_name = schema_name
      @schema_version = schema_version
      @request_payload = request_payload
      @started_at = started_at
      @call_record = nil
    end

    def start!
      @call_record = task.llm_calls.create!(
        purpose: purpose,
        model: model,
        reasoning_effort: reasoning_effort,
        schema_name: schema_name,
        schema_version: schema_version,
        attempt: next_attempt,
        started_at: started_at,
        request_json: redact(request_payload)
      )
    end

    def complete!(response:, completed_at: Time.current, **)
      call_record.complete!(
        response_json: redact(response),
        usage_json: usage_from(response),
        openai_response_id: response_id(response),
        openai_request_id: request_id(response),
        openai_trace_id: trace_id(response),
        duration_ms: duration_ms(completed_at),
        completed_at: completed_at
      )
    end

    def fail!(error:, response: {}, completed_at: Time.current, **)
      call_record.fail!(
        error_json: {
          class: error.class.name,
          message: redact_string(error.message, keep_bearer: false),
          retryable: retryable?(error)
        },
        response_json: redact(response || {}),
        duration_ms: duration_ms(completed_at),
        completed_at: completed_at
      )
    end

    def self.redact(value)
      new(task: nil, purpose: nil, model: nil, request_payload: nil).send(:redact, value)
    end

    private

    attr_reader :task, :purpose, :model, :reasoning_effort, :schema_name, :schema_version, :request_payload, :started_at, :call_record

    def next_attempt
      task.llm_calls.maximum(:attempt).to_i + 1
    end

    def usage_from(response)
      value_from(response, "usage") || {}
    end

    def response_id(response)
      value_from(response, "id")
    end

    def request_id(response)
      value_from(response, "request_id")
    end

    def trace_id(response)
      value_from(response, "trace_id")
    end

    def value_from(object, key)
      if object.respond_to?(:[])
        object[key] || object[key.to_sym]
      elsif object.respond_to?(key)
        object.public_send(key)
      end
    end

    def duration_ms(completed_at)
      ((completed_at - started_at) * 1000).round
    end

    def retryable?(error)
      error.is_a?(Timeout::Error) || error.class.name.include?("Timeout") || error.class.name.include?("RateLimit")
    end

    def redact(value)
      case value
      when Hash
        value.transform_values.with_index do |entry, index|
          key = value.keys[index]
          SECRET_KEYS.include?(key.to_s) ? redact_secret_value(entry) : redact(entry)
        end
      when Array
        value.map { |entry| redact(entry) }
      when String
        redact_string(value)
      else
        value
      end
    end

    def redact_secret_value(value)
      value.to_s.start_with?("Bearer ") ? "Bearer [REDACTED]" : "[REDACTED]"
    end

    def redact_string(value, keep_bearer: true)
      bearer_replacement = keep_bearer ? "Bearer [REDACTED]" : "[REDACTED]"
      value.gsub(BEARER_PATTERN, bearer_replacement).gsub(SECRET_PATTERN, "[REDACTED]")
    end
  end
end
