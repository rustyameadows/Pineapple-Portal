class NormalizeVendorContacts < ActiveRecord::Migration[8.0]
  CONTACT_KEYS = %w[name title email phone notes].freeze
  EVENT_VENDOR_GLOBAL_INDEX = "index_event_vendors_on_event_and_global_vendor".freeze

  class GlobalVendorRecord < ActiveRecord::Base
    self.table_name = "global_vendors"
  end

  class EventVendorRecord < ActiveRecord::Base
    self.table_name = "event_vendors"
  end

  class GlobalVendorContactRecord < ActiveRecord::Base
    self.table_name = "global_vendor_contacts"
  end

  class EventVendorContactRecord < ActiveRecord::Base
    self.table_name = "event_vendor_contacts"
  end

  class ContactBackfill
    def initialize
      @expected_global_contact_count = 0
      @expected_selection_count = 0
    end

    def call
      reset_contact_models

      GlobalVendorRecord.order(:id).find_each do |global_vendor|
        backfill_global_vendor(global_vendor)
      end

      verify_counts!
      verify_selection_ownership!
    end

    private

    attr_reader :expected_global_contact_count, :expected_selection_count

    def reset_contact_models
      GlobalVendorContactRecord.reset_column_information
      EventVendorContactRecord.reset_column_information
    end

    def backfill_global_vendor(global_vendor)
      global_contacts = normalize_contacts(
        global_vendor.contacts_jsonb,
        source: "global_vendor:#{global_vendor.id}"
      )
      event_sources = EventVendorRecord
                      .where(global_vendor_id: global_vendor.id)
                      .order(:position, :id)
                      .pluck(:id, :contacts_jsonb)
                      .map do |event_vendor_id, contacts_jsonb|
        {
          event_vendor_id:,
          contacts: normalize_contacts(
            contacts_jsonb,
            source: "event_vendor:#{event_vendor_id}"
          )
        }
      end

      directory = unique_contacts(global_contacts + event_sources.flat_map { |source| source.fetch(:contacts) })
      contacts_by_fingerprint = create_global_contacts(global_vendor.id, directory)

      event_sources.each do |source|
        selected_contacts = source.fetch(:contacts).presence || global_contacts
        create_event_selections(
          source.fetch(:event_vendor_id),
          selected_contacts,
          contacts_by_fingerprint
        )
      end
    end

    def normalize_contacts(raw_contacts, source:)
      unless raw_contacts.is_a?(Array)
        raise ActiveRecord::MigrationError, "#{source} contacts_jsonb must be an array"
      end

      raw_contacts.filter_map.with_index do |raw_contact, index|
        unless raw_contact.is_a?(Hash)
          raise ActiveRecord::MigrationError, "#{source} contact #{index} must be an object"
        end

        stringified = raw_contact.stringify_keys
        unknown_keys = stringified.keys - CONTACT_KEYS
        if unknown_keys.any?
          raise ActiveRecord::MigrationError,
                "#{source} contact #{index} has unsupported keys: #{unknown_keys.sort.join(', ')}"
        end

        normalized = CONTACT_KEYS.index_with do |key|
          normalize_contact_value(stringified[key], source:, index:, key:)
        end
        next if normalized.values.all?(&:nil?)

        normalized
      end
    end

    def normalize_contact_value(value, source:, index:, key:)
      return if value.nil?

      unless value.is_a?(String)
        raise ActiveRecord::MigrationError,
              "#{source} contact #{index} field #{key} must be a string or null"
      end

      value.strip.presence
    end

    def unique_contacts(contacts)
      contacts.each_with_object({}) do |contact, unique|
        unique[fingerprint(contact)] ||= contact
      end.values
    end

    def create_global_contacts(global_vendor_id, contacts)
      contacts.each_with_index.to_h do |contact, position|
        record = GlobalVendorContactRecord.create!(
          contact.merge(
            global_vendor_id:,
            position:,
            created_at: Time.current,
            updated_at: Time.current
          )
        )
        @expected_global_contact_count += 1
        [ fingerprint(contact), record.id ]
      end
    end

    def create_event_selections(event_vendor_id, contacts, contacts_by_fingerprint)
      unique_contacts(contacts).each_with_index do |contact, position|
        contact_id = contacts_by_fingerprint.fetch(fingerprint(contact))
        EventVendorContactRecord.create!(
          event_vendor_id:,
          global_vendor_contact_id: contact_id,
          position:,
          created_at: Time.current,
          updated_at: Time.current
        )
        @expected_selection_count += 1
      end
    end

    def fingerprint(contact)
      CONTACT_KEYS.map { |key| contact[key] }
    end

    def verify_counts!
      actual_contact_count = GlobalVendorContactRecord.count
      actual_selection_count = EventVendorContactRecord.count

      unless actual_contact_count == expected_global_contact_count
        raise ActiveRecord::MigrationError,
              "Expected #{expected_global_contact_count} global vendor contacts, found #{actual_contact_count}"
      end
      return if actual_selection_count == expected_selection_count

      raise ActiveRecord::MigrationError,
            "Expected #{expected_selection_count} event vendor contact selections, found #{actual_selection_count}"
    end

    def verify_selection_ownership!
      invalid_count = EventVendorContactRecord.connection.select_value(<<~SQL.squish).to_i
        SELECT COUNT(*)
        FROM event_vendor_contacts selections
        INNER JOIN event_vendors
          ON event_vendors.id = selections.event_vendor_id
        INNER JOIN global_vendor_contacts contacts
          ON contacts.id = selections.global_vendor_contact_id
        WHERE event_vendors.global_vendor_id <> contacts.global_vendor_id
      SQL
      return if invalid_count.zero?

      raise ActiveRecord::MigrationError,
            "Found #{invalid_count} event contact selections belonging to the wrong global vendor"
    end
  end

  def up
    verify_event_vendor_links!

    create_table :global_vendor_contacts do |t|
      t.references :global_vendor, null: false, foreign_key: { on_delete: :cascade }
      t.string :name
      t.string :title
      t.string :email
      t.string :phone
      t.text :notes
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :global_vendor_contacts,
              %i[global_vendor_id position id],
              name: "index_global_vendor_contacts_on_vendor_position"
    add_check_constraint :global_vendor_contacts,
                         "position >= 0",
                         name: "global_vendor_contacts_position_non_negative"
    add_check_constraint :global_vendor_contacts,
                         <<~SQL.squish,
                           num_nonnulls(
                             NULLIF(BTRIM(name), ''),
                             NULLIF(BTRIM(title), ''),
                             NULLIF(BTRIM(email), ''),
                             NULLIF(BTRIM(phone), ''),
                             NULLIF(BTRIM(notes), '')
                           ) > 0
                         SQL
                         name: "global_vendor_contacts_not_blank"

    create_table :event_vendor_contacts do |t|
      t.references :event_vendor, null: false, foreign_key: { on_delete: :cascade }
      t.references :global_vendor_contact, null: false, foreign_key: { on_delete: :cascade }
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :event_vendor_contacts,
              %i[event_vendor_id global_vendor_contact_id],
              unique: true,
              name: "index_event_vendor_contacts_on_vendor_and_contact"
    add_index :event_vendor_contacts,
              %i[event_vendor_id position id],
              name: "index_event_vendor_contacts_on_vendor_position"
    add_check_constraint :event_vendor_contacts,
                         "position >= 0",
                         name: "event_vendor_contacts_position_non_negative"

    ContactBackfill.new.call

    add_index :event_vendors,
              %i[event_id global_vendor_id],
              unique: true,
              name: EVENT_VENDOR_GLOBAL_INDEX
    change_column_null :event_vendors, :global_vendor_id, false
  end

  def down
    change_column_null :event_vendors, :global_vendor_id, true
    remove_index :event_vendors, name: EVENT_VENDOR_GLOBAL_INDEX
    drop_table :event_vendor_contacts
    drop_table :global_vendor_contacts
  end

  private

  def verify_event_vendor_links!
    unlinked_count = EventVendorRecord.where(global_vendor_id: nil).count
    if unlinked_count.positive?
      raise ActiveRecord::MigrationError,
            "Cannot normalize vendor contacts with #{unlinked_count} unlinked event vendors"
    end

    duplicate_groups = EventVendorRecord
                       .group(:event_id, :global_vendor_id)
                       .having("COUNT(*) > 1")
                       .count
    return if duplicate_groups.empty?

    raise ActiveRecord::MigrationError,
          "Cannot normalize vendor contacts with #{duplicate_groups.length} duplicate event/global vendor groups"
  end
end
