require "json"
require "set"

module Vendors
  class Audit
    BATCH_SIZE = 1_000
    CONTACT_KEYS = %w[name title email phone notes].freeze
    MULTIPLE_VENDOR_DELIMITER = /\r?\n|;|\||\s+(?:\/|\+)\s+/.freeze
    PLACEHOLDER_PATTERN = /\b(?:tbd|tba|unknown|n\/a|none|not selected|to be determined|to be announced)\b/i.freeze

    METRIC_KEYS = %i[
      global_vendors_total
      global_vendors_unused
      event_vendors_total
      event_vendors_linked
      event_vendors_unlinked
      duplicate_event_global_groups
      event_vendors_in_duplicate_groups
      linked_event_vendor_name_mismatches
      linked_vendor_type_values_differ
      linked_social_handle_values_differ
      event_vendors_with_local_contacts
      unlinked_event_vendors_with_local_contacts
      linked_contacts_equal
      linked_local_contacts_only
      linked_global_contacts_only
      linked_contacts_different
      linked_contact_mismatches
      event_vendors_with_malformed_contact_entries
      global_vendors_with_malformed_contact_entries
      event_vendors_with_unknown_contact_keys
      global_vendors_with_unknown_contact_keys
      global_vendor_contacts_total
      event_vendor_contact_selections_total
      legacy_global_contacts_missing_from_directory
      legacy_event_contacts_missing_from_directory
      expected_event_contact_selections_missing
      cross_global_event_contact_selections
      duplicate_event_contact_selection_pairs
      global_vendors_without_directory_contacts
      event_vendors_without_contact_selections
      calendar_items_with_vendor_value
      calendar_items_with_blank_vendor_value
      ros_items_with_vendor_value
      derived_calendar_items_with_vendor_value
      vendor_values_exact_match
      vendor_values_normalized_match
      vendor_values_ambiguous
      vendor_values_unmatched
      unmatched_placeholder_values
      unmatched_suspected_multiple_values
      unmatched_other_values
      suspected_multiple_all_parts_match
      suspected_multiple_some_parts_match
      suspected_multiple_no_parts_match
    ].freeze

    class Report
      attr_reader :metrics

      def initialize(metrics)
        @metrics = METRIC_KEYS.index_with { |key| Integer(metrics.fetch(key, 0)) }.freeze
      end

      def to_s
        METRIC_KEYS.map { |key| "#{key}=#{metrics.fetch(key)}" }.join("\n")
      end
    end

    def self.run
      connection = ActiveRecord::Base.connection

      connection.transaction(isolation: :repeatable_read, requires_new: true) do
        connection.execute("SET TRANSACTION READ ONLY")
        ActiveRecord::Base.while_preventing_writes do
          ActiveRecord::Base.uncached { new.call }
        end
      end
    end

    def initialize
      @metrics = METRIC_KEYS.index_with(0)
    end

    def call
      collect_inventory
      collect_event_vendor_details
      collect_global_contact_shape
      collect_normalized_contact_details
      collect_calendar_vendor_values
      Report.new(metrics)
    end

    private

    attr_reader :metrics

    def collect_inventory
      metrics[:global_vendors_total] = GlobalVendor.count
      metrics[:global_vendors_unused] = GlobalVendor
                                        .where.not(id: EventVendor.where.not(global_vendor_id: nil).select(:global_vendor_id))
                                        .count
      metrics[:event_vendors_total] = EventVendor.count
      metrics[:event_vendors_linked] = EventVendor.where.not(global_vendor_id: nil).count
      metrics[:event_vendors_unlinked] = EventVendor.where(global_vendor_id: nil).count

      duplicate_counts = duplicate_event_global_counts
      metrics[:duplicate_event_global_groups] = duplicate_counts.fetch("group_count").to_i
      metrics[:event_vendors_in_duplicate_groups] = duplicate_counts.fetch("vendor_count").to_i
    end

    def duplicate_event_global_counts
      grouped_sql = EventVendor
                    .where.not(global_vendor_id: nil)
                    .group(:event_id, :global_vendor_id)
                    .having("COUNT(*) > 1")
                    .select("COUNT(*) AS vendor_count")
                    .to_sql

      EventVendor.connection.select_one(<<~SQL.squish)
        SELECT COUNT(*) AS group_count, COALESCE(SUM(vendor_count), 0) AS vendor_count
        FROM (#{grouped_sql}) duplicate_event_global_groups
      SQL
    end

    def collect_event_vendor_details
      EventVendor.in_batches(of: BATCH_SIZE) do |batch|
        rows = batch.pluck(:global_vendor_id, :name, :vendor_type, :social_handle, :contacts_jsonb)
        globals = globals_for(rows.filter_map(&:first).uniq)

        rows.each do |global_vendor_id, name, vendor_type, social_handle, local_contacts|
          inspect_contact_shape(local_contacts, prefix: :event_vendors)
          local_present = contact_list_present?(local_contacts)
          metrics[:event_vendors_with_local_contacts] += 1 if local_present

          if global_vendor_id.nil?
            metrics[:unlinked_event_vendors_with_local_contacts] += 1 if local_present
            next
          end

          global = globals.fetch(global_vendor_id)
          metrics[:linked_event_vendor_name_mismatches] += 1 if GlobalVendor.normalize_name(name) != global.fetch(:normalized_name)
          metrics[:linked_vendor_type_values_differ] += 1 if profile_value(vendor_type) != profile_value(global.fetch(:vendor_type))
          metrics[:linked_social_handle_values_differ] += 1 if profile_value(social_handle) != profile_value(global.fetch(:social_handle))

          classify_linked_contacts(local_contacts, global.fetch(:contacts))
        end
      end
    end

    def globals_for(ids)
      return {} if ids.empty?

      GlobalVendor.where(id: ids).pluck(
        :id,
        :normalized_name,
        :default_vendor_type,
        :default_social_handle,
        :contacts_jsonb
      ).to_h do |id, normalized_name, vendor_type, social_handle, contacts|
        [ id, { normalized_name:, vendor_type:, social_handle:, contacts: } ]
      end
    end

    def profile_value(value)
      value.to_s.strip.downcase.presence
    end

    def classify_linked_contacts(local_contacts, global_contacts)
      local = canonical_contacts(local_contacts)
      global = canonical_contacts(global_contacts)
      local_present = local.any?
      global_present = global.any?

      if local == global
        metrics[:linked_contacts_equal] += 1
      elsif local_present && !global_present
        metrics[:linked_local_contacts_only] += 1
        metrics[:linked_contact_mismatches] += 1
      elsif !local_present && global_present
        metrics[:linked_global_contacts_only] += 1
        metrics[:linked_contact_mismatches] += 1
      else
        metrics[:linked_contacts_different] += 1
        metrics[:linked_contact_mismatches] += 1
      end
    end

    def collect_global_contact_shape
      GlobalVendor.in_batches(of: BATCH_SIZE) do |batch|
        batch.pluck(:contacts_jsonb).each do |contacts|
          inspect_contact_shape(contacts, prefix: :global_vendors)
        end
      end
    end

    def inspect_contact_shape(raw_contacts, prefix:)
      contacts = raw_contacts.is_a?(Array) ? raw_contacts : []
      malformed = !raw_contacts.is_a?(Array) || contacts.any? { |contact| !contact.is_a?(Hash) }
      unknown_keys = contacts.any? do |contact|
        contact.is_a?(Hash) && (contact.keys.map(&:to_s) - CONTACT_KEYS).any?
      end

      metrics[:"#{prefix}_with_malformed_contact_entries"] += 1 if malformed
      metrics[:"#{prefix}_with_unknown_contact_keys"] += 1 if unknown_keys
    end

    def canonical_contacts(raw_contacts)
      return [] unless raw_contacts.is_a?(Array)

      raw_contacts.filter_map do |contact|
        next unless contact.is_a?(Hash)

        normalized = CONTACT_KEYS.index_with(nil)
        contact.each do |key, value|
          normalized[key.to_s] = normalize_json_value(value)
        end
        next unless normalized.values.any?

        JSON.generate(normalized.sort.to_h)
      end.sort
    end

    def normalize_json_value(value)
      case value
      when String
        value.strip.presence
      when Hash
        value.to_h.transform_keys(&:to_s).sort.to_h.transform_values { |nested| normalize_json_value(nested) }
      when Array
        value.map { |nested| normalize_json_value(nested) }
      else
        value
      end
    end

    def contact_list_present?(contacts)
      canonical_contacts(contacts).any?
    end

    def collect_normalized_contact_details
      metrics[:global_vendor_contacts_total] = table_count("global_vendor_contacts")
      metrics[:event_vendor_contact_selections_total] = table_count("event_vendor_contacts")
      metrics[:global_vendors_without_directory_contacts] = GlobalVendor
                                                            .where(<<~SQL.squish)
                                                              NOT EXISTS (
                                                                SELECT 1
                                                                FROM global_vendor_contacts contacts
                                                                WHERE contacts.global_vendor_id = global_vendors.id
                                                              )
                                                            SQL
                                                            .count
      metrics[:event_vendors_without_contact_selections] = EventVendor
                                                           .where(<<~SQL.squish)
                                                             NOT EXISTS (
                                                               SELECT 1
                                                               FROM event_vendor_contacts selections
                                                               WHERE selections.event_vendor_id = event_vendors.id
                                                             )
                                                           SQL
                                                           .count
      metrics[:cross_global_event_contact_selections] = cross_global_event_contact_selection_count
      metrics[:duplicate_event_contact_selection_pairs] = duplicate_event_contact_selection_pair_count

      collect_missing_global_directory_contacts
      collect_missing_event_directory_contacts_and_selections
    end

    def table_count(table_name)
      ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{table_name}").to_i
    end

    def cross_global_event_contact_selection_count
      ActiveRecord::Base.connection.select_value(<<~SQL.squish).to_i
        SELECT COUNT(*)
        FROM event_vendor_contacts selections
        INNER JOIN event_vendors
          ON event_vendors.id = selections.event_vendor_id
        INNER JOIN global_vendor_contacts contacts
          ON contacts.id = selections.global_vendor_contact_id
        WHERE event_vendors.global_vendor_id IS DISTINCT FROM contacts.global_vendor_id
      SQL
    end

    def duplicate_event_contact_selection_pair_count
      ActiveRecord::Base.connection.select_value(<<~SQL.squish).to_i
        SELECT COUNT(*)
        FROM (
          SELECT event_vendor_id, global_vendor_contact_id
          FROM event_vendor_contacts
          GROUP BY event_vendor_id, global_vendor_contact_id
          HAVING COUNT(*) > 1
        ) duplicate_pairs
      SQL
    end

    def collect_missing_global_directory_contacts
      GlobalVendor.in_batches(of: BATCH_SIZE) do |batch|
        rows = batch.pluck(:id, :contacts_jsonb)
        directory = directory_contact_fingerprints_for(rows.map(&:first))

        rows.each do |global_vendor_id, legacy_contacts|
          expected = unique_contact_fingerprints(legacy_contacts)
          metrics[:legacy_global_contacts_missing_from_directory] +=
            (expected - directory.fetch(global_vendor_id, Set.new)).length
        end
      end
    end

    def collect_missing_event_directory_contacts_and_selections
      EventVendor.in_batches(of: BATCH_SIZE) do |batch|
        rows = batch.pluck(:id, :global_vendor_id, :contacts_jsonb)
        global_ids = rows.filter_map { |(_event_vendor_id, global_vendor_id, _contacts)| global_vendor_id }.uniq
        global_legacy_contacts = GlobalVendor.where(id: global_ids).pluck(:id, :contacts_jsonb).to_h
        directory = directory_contact_fingerprints_for(global_ids)
        selected = selected_contact_fingerprints_for(rows.map(&:first))

        rows.each do |event_vendor_id, global_vendor_id, legacy_event_contacts|
          local = unique_contact_fingerprints(legacy_event_contacts)
          global = unique_contact_fingerprints(global_legacy_contacts[global_vendor_id])
          directory_contacts = directory.fetch(global_vendor_id, Set.new)

          metrics[:legacy_event_contacts_missing_from_directory] +=
            (local - directory_contacts).length

          expected_selections = local.any? ? local : global
          metrics[:expected_event_contact_selections_missing] +=
            (expected_selections - selected.fetch(event_vendor_id, Set.new)).length
        end
      end
    end

    def directory_contact_fingerprints_for(global_vendor_ids)
      contacts = Hash.new { |hash, key| hash[key] = Set.new }
      return contacts if global_vendor_ids.empty?

      rows = ActiveRecord::Base.connection.select_rows(<<~SQL.squish)
        SELECT global_vendor_id, name, title, email, phone, notes
        FROM global_vendor_contacts
        WHERE global_vendor_id IN (#{global_vendor_ids.map { |id| Integer(id) }.join(', ')})
      SQL
      rows.each do |global_vendor_id, name, title, email, phone, notes|
        contacts[global_vendor_id.to_i] << contact_fingerprint(name:, title:, email:, phone:, notes:)
      end
      contacts
    end

    def selected_contact_fingerprints_for(event_vendor_ids)
      contacts = Hash.new { |hash, key| hash[key] = Set.new }
      return contacts if event_vendor_ids.empty?

      rows = ActiveRecord::Base.connection.select_rows(<<~SQL.squish)
        SELECT
          selections.event_vendor_id,
          event_vendors.global_vendor_id,
          contacts.global_vendor_id,
          contacts.name,
          contacts.title,
          contacts.email,
          contacts.phone,
          contacts.notes
        FROM event_vendor_contacts selections
        INNER JOIN event_vendors
          ON event_vendors.id = selections.event_vendor_id
        INNER JOIN global_vendor_contacts contacts
          ON contacts.id = selections.global_vendor_contact_id
        WHERE selections.event_vendor_id IN (#{event_vendor_ids.map { |id| Integer(id) }.join(', ')})
      SQL
      rows.each do |event_vendor_id, event_global_id, contact_global_id, name, title, email, phone, notes|
        next unless event_global_id.to_i == contact_global_id.to_i

        contacts[event_vendor_id.to_i] << contact_fingerprint(name:, title:, email:, phone:, notes:)
      end
      contacts
    end

    def unique_contact_fingerprints(raw_contacts)
      canonical_contacts(raw_contacts).to_set
    end

    def contact_fingerprint(name:, title:, email:, phone:, notes:)
      canonical_contacts([
        {
          "name" => name,
          "title" => title,
          "email" => email,
          "phone" => phone,
          "notes" => notes
        }
      ]).first
    end

    def collect_calendar_vendor_values
      CalendarItem.where.not(vendor_name: nil).in_batches(of: BATCH_SIZE) do |batch|
        rows = batch.joins(:event_calendar).pluck(
          "event_calendars.event_id",
          "event_calendars.kind",
          "calendar_items.vendor_name"
        )
        candidates = vendor_candidates_for(rows.map(&:first).uniq)

        rows.each do |event_id, calendar_kind, raw_value|
          value = raw_value.to_s.strip
          if value.blank?
            metrics[:calendar_items_with_blank_vendor_value] += 1
            next
          end

          metrics[:calendar_items_with_vendor_value] += 1
          if calendar_kind == EventCalendar::KINDS[:master]
            metrics[:ros_items_with_vendor_value] += 1
          else
            metrics[:derived_calendar_items_with_vendor_value] += 1
          end

          classification = classify_vendor_value(value, candidates.fetch(event_id, []))
          metrics[:"vendor_values_#{classification}_match"] += 1 if %i[exact normalized].include?(classification)
          metrics[:vendor_values_ambiguous] += 1 if classification == :ambiguous
          classify_unmatched_value(value, candidates.fetch(event_id, [])) if classification == :unmatched
        end
      end
    end

    def vendor_candidates_for(event_ids)
      candidates = Hash.new { |hash, key| hash[key] = [] }
      return candidates if event_ids.empty?

      EventVendor.where(event_id: event_ids).left_joins(:global_vendor).pluck(
        :event_id,
        :id,
        :name,
        "global_vendors.name"
      ).each do |event_id, event_vendor_id, event_name, global_name|
        candidates[event_id] << {
          id: event_vendor_id,
          aliases: [ event_name, global_name ].filter_map { |name| name.to_s.strip.presence }.uniq
        }
      end
      candidates
    end

    def classify_vendor_value(value, candidates)
      exact_ids = matching_candidate_ids(candidates) { |alias_name| alias_name == value }
      return :exact if exact_ids.one?
      return :ambiguous if exact_ids.many?

      normalized_value = GlobalVendor.normalize_name(value)
      normalized_ids = matching_candidate_ids(candidates) do |alias_name|
        GlobalVendor.normalize_name(alias_name) == normalized_value
      end
      return :normalized if normalized_ids.one?
      return :ambiguous if normalized_ids.many?

      :unmatched
    end

    def matching_candidate_ids(candidates)
      candidates.filter_map do |candidate|
        candidate.fetch(:id) if candidate.fetch(:aliases).any? { |alias_name| yield(alias_name) }
      end.uniq
    end

    def classify_unmatched_value(value, candidates)
      metrics[:vendor_values_unmatched] += 1
      parts = value.split(MULTIPLE_VENDOR_DELIMITER).map(&:strip).reject(&:blank?)

      if parts.many?
        metrics[:unmatched_suspected_multiple_values] += 1
        uniquely_matched_parts = parts.count do |part|
          %i[exact normalized].include?(classify_vendor_value(part, candidates))
        end
        if uniquely_matched_parts == parts.length
          metrics[:suspected_multiple_all_parts_match] += 1
        elsif uniquely_matched_parts.positive?
          metrics[:suspected_multiple_some_parts_match] += 1
        else
          metrics[:suspected_multiple_no_parts_match] += 1
        end
      elsif value.match?(PLACEHOLDER_PATTERN)
        metrics[:unmatched_placeholder_values] += 1
      else
        metrics[:unmatched_other_values] += 1
      end
    end
  end
end
