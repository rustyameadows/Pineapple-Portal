module RosAgent
  module OpenaiResponse
    MISSING = Object.new.freeze

    module_function

    def value(object, key, default: nil)
      result = lookup(object, key)
      result.equal?(MISSING) ? default : result
    end

    def json_safe(value)
      case value
      when Hash
        value.each_with_object({}) do |(key, entry), hash|
          hash[key.to_s] = json_safe(entry)
        end
      when Array
        value.map { |entry| json_safe(entry) }
      when String, Numeric, TrueClass, FalseClass, NilClass
        value
      when Symbol
        value.to_s
      when Time, Date, DateTime
        value.iso8601
      else
        converted = convert_to_hash(value)
        return json_safe(converted) unless converted.equal?(MISSING)

        value.to_s
      end
    end

    def lookup(object, key)
      return MISSING if object.nil?

      string_key = key.to_s
      symbol_key = key.to_sym

      if object.is_a?(Hash)
        return object[string_key] if object.key?(string_key)
        return object[symbol_key] if object.key?(symbol_key)
      end

      value = bracket_value(object, symbol_key)
      return value unless value.equal?(MISSING)

      value = bracket_value(object, string_key)
      return value unless value.equal?(MISSING)

      return object.public_send(string_key) if object.respond_to?(string_key)

      MISSING
    end

    def bracket_value(object, key)
      return MISSING unless object.respond_to?(:[])

      object[key]
    rescue ArgumentError, KeyError, IndexError, TypeError
      MISSING
    end

    def convert_to_hash(value)
      return MISSING unless value.respond_to?(:to_h)

      converted = value.to_h
      converted.equal?(value) ? MISSING : converted
    rescue StandardError
      MISSING
    end
  end
end
