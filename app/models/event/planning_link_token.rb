class Event
  module PlanningLinkToken
    module_function

    BUILTIN_PREFIX = "builtin".freeze
    EVENT_LINK_PREFIX = "event_link".freeze

    def built_in(key)
      token_for(BUILTIN_PREFIX, key)
    end

    def event_link(id)
      token_for(EVENT_LINK_PREFIX, id)
    end

    def built_in?(token, key = nil)
      return false unless token.start_with?("#{BUILTIN_PREFIX}:")

      return true if key.nil?

      token_value(token) == key.to_s
    end

    def event_link?(token, id = nil)
      return false unless token.start_with?("#{EVENT_LINK_PREFIX}:")

      return true if id.nil?

      token_value(token) == id.to_s
    end

    def valid?(token, event:)
      if built_in?(token)
        ClientPortal::PlanningLinks.built_in_keys.include?(token_value(token))
      elsif event_link?(token)
        event.event_links.planning.exists?(id: token_value(token))
      else
        false
      end
    end

    def token_value(token)
      token.split(":", 2).last
    end

    def token_for(prefix, value)
      "#{prefix}:#{value}"
    end
  end
end
