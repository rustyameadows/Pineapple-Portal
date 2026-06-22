module RosAgent
  module Schemas
    module SchemaValidator
      module_function

      def require_object!(payload, keys)
        raise ArgumentError, "payload must be a Hash" unless payload.is_a?(Hash)

        keys.each { |key| raise ArgumentError, "#{key} is required" unless payload.key?(key) }
      end

      def require_present!(payload, key)
        raise ArgumentError, "#{key} is required" if payload[key].blank?
      end

      def require_array!(payload, key, allow_empty: true)
        value = payload[key]
        raise ArgumentError, "#{key} must be an Array" unless value.is_a?(Array)
        raise ArgumentError, "#{key} must not be empty" if !allow_empty && value.empty?
      end

      def duplicate_values(values)
        values.group_by(&:itself).select { |_value, entries| entries.length > 1 }.keys
      end
    end
  end
end
