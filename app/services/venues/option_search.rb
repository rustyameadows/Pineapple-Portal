module Venues
  class OptionSearch
    Result = Struct.new(:global_venue, :score, :is_active_on_event, :usage_count, :matched_by, keyword_init: true)

    LIMIT = 20

    def initialize(event:, query:, limit: LIMIT)
      @event = event
      @query = query.to_s.strip
      @normalized_query = GlobalVenue.normalize_name(@query)
      @limit = limit.to_i.positive? ? [limit.to_i, 50].min : LIMIT
    end

    def call
      active_ids = @event.event_venues.where.not(global_venue_id: nil).pluck(:global_venue_id)
      usage_counts = EventVenue.where.not(global_venue_id: nil).group(:global_venue_id).count

      base_scope = GlobalVenue.all
      base_scope = base_scope.where("LOWER(name) LIKE ?", "%#{@normalized_query}%") if @normalized_query.present?

      candidates = base_scope.limit(250).to_a

      ranked = candidates.map do |global_venue|
        matched_by, match_score = match_score_for(global_venue)
        active_boost = active_ids.include?(global_venue.id) ? 100 : 0
        usage_count = usage_counts[global_venue.id].to_i
        usage_boost = [usage_count, 20].min

        Result.new(
          global_venue: global_venue,
          score: match_score + active_boost + usage_boost,
          is_active_on_event: active_ids.include?(global_venue.id),
          usage_count: usage_count,
          matched_by: matched_by
        )
      end

      ranked
        .sort_by { |row| [-row.score, row.global_venue.name.downcase, row.global_venue.id] }
        .first(@limit)
    end

    private

    def match_score_for(global_venue)
      return ["all", 1] if @normalized_query.blank?

      normalized_name = global_venue.normalized_name
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
