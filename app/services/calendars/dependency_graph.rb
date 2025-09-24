require "set"

module Calendars
  class DependencyGraph
    def initialize(item)
      @item = item
    end

    def circular?
      return false unless item.relative_anchor

      visited = Set.new
      cursor = item.relative_anchor

      while cursor
        return true if same_node?(cursor)
        node_id = cursor.id || cursor.object_id
        return true if visited.include?(node_id)

        visited.add(node_id)
        cursor = cursor.relative_anchor
      end

      false
    end

    private

    attr_reader :item

    def same_node?(other)
      return true if other.equal?(item)
      return false unless other.id && item.id

      other.id == item.id
    end
  end
end
