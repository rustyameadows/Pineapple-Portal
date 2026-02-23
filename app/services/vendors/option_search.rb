module Vendors
  class OptionSearch
    Result = Struct.new(:global_vendor, :score, :is_active_on_event, :usage_count, :matched_by, keyword_init: true)

    LIMIT = 20

    def initialize(event:, query:, limit: LIMIT)
      @event = event
      @query = query.to_s.strip
      @normalized_query = GlobalVendor.normalize_name(@query)
      @limit = limit.to_i.positive? ? [limit.to_i, 50].min : LIMIT
    end

    def call
      active_ids = @event.event_vendors.where.not(global_vendor_id: nil).pluck(:global_vendor_id)
      usage_counts = EventVendor.where.not(global_vendor_id: nil).group(:global_vendor_id).count

      base_scope = GlobalVendor.all
      base_scope = base_scope.where("LOWER(name) LIKE ?", "%#{@normalized_query}%") if @normalized_query.present?

      candidates = base_scope.limit(250).to_a

      ranked = candidates.map do |global_vendor|
        matched_by, match_score = match_score_for(global_vendor)
        active_boost = active_ids.include?(global_vendor.id) ? 100 : 0
        usage_count = usage_counts[global_vendor.id].to_i
        usage_boost = [usage_count, 20].min

        Result.new(
          global_vendor: global_vendor,
          score: match_score + active_boost + usage_boost,
          is_active_on_event: active_ids.include?(global_vendor.id),
          usage_count: usage_count,
          matched_by: matched_by
        )
      end

      ranked
        .sort_by { |row| [-row.score, row.global_vendor.name.downcase, row.global_vendor.id] }
        .first(@limit)
    end

    private

    def match_score_for(global_vendor)
      return ["all", 1] if @normalized_query.blank?

      normalized_name = global_vendor.normalized_name
      if normalized_name == @normalized_query
        ["exact", 300]
      elsif normalized_name.start_with?(@normalized_query)
        ["prefix", 200]
      elsif normalized_name.include?(@normalized_query)
        ["substring", 120]
      else
        ["all", 1]
      end
    end
  end
end
