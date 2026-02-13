class AddGlobalVendorsAndVenues < ActiveRecord::Migration[8.0]
  def up
    create_table :global_vendors do |t|
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.string :default_vendor_type
      t.string :default_social_handle
      t.timestamps
    end

    add_index :global_vendors, :normalized_name, unique: true
    add_index :global_vendors, :name

    create_table :global_venues do |t|
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.timestamps
    end

    add_index :global_venues, :normalized_name, unique: true
    add_index :global_venues, :name

    add_reference :event_vendors, :global_vendor, foreign_key: true
    add_reference :event_venues, :global_venue, foreign_key: true

    backfill_global_vendors!
    backfill_global_venues!
  end

  def down
    remove_reference :event_venues, :global_venue, foreign_key: true
    remove_reference :event_vendors, :global_vendor, foreign_key: true

    drop_table :global_venues
    drop_table :global_vendors
  end

  private

  def backfill_global_vendors!
    execute <<~SQL.squish
      INSERT INTO global_vendors (name, normalized_name, default_vendor_type, default_social_handle, created_at, updated_at)
      SELECT DISTINCT ON (normalized_name)
        trimmed_name AS name,
        normalized_name,
        NULLIF(BTRIM(vendor_type), '') AS default_vendor_type,
        NULLIF(BTRIM(social_handle), '') AS default_social_handle,
        NOW(),
        NOW()
      FROM (
        SELECT
          name,
          BTRIM(name) AS trimmed_name,
          REGEXP_REPLACE(LOWER(BTRIM(name)), '\s+', ' ', 'g') AS normalized_name,
          vendor_type,
          social_handle,
          created_at
        FROM event_vendors
        WHERE BTRIM(COALESCE(name, '')) <> ''
      ) source
      ORDER BY normalized_name, created_at ASC;
    SQL

    execute <<~SQL.squish
      UPDATE event_vendors ev
      SET global_vendor_id = gv.id
      FROM global_vendors gv
      WHERE gv.normalized_name = REGEXP_REPLACE(LOWER(BTRIM(ev.name)), '\s+', ' ', 'g')
        AND ev.global_vendor_id IS NULL;
    SQL
  end

  def backfill_global_venues!
    execute <<~SQL.squish
      INSERT INTO global_venues (name, normalized_name, created_at, updated_at)
      SELECT DISTINCT ON (normalized_name)
        trimmed_name AS name,
        normalized_name,
        NOW(),
        NOW()
      FROM (
        SELECT
          name,
          BTRIM(name) AS trimmed_name,
          REGEXP_REPLACE(LOWER(BTRIM(name)), '\s+', ' ', 'g') AS normalized_name,
          created_at
        FROM event_venues
        WHERE BTRIM(COALESCE(name, '')) <> ''
      ) source
      ORDER BY normalized_name, created_at ASC;
    SQL

    execute <<~SQL.squish
      UPDATE event_venues ev
      SET global_venue_id = gv.id
      FROM global_venues gv
      WHERE gv.normalized_name = REGEXP_REPLACE(LOWER(BTRIM(ev.name)), '\s+', ' ', 'g')
        AND ev.global_venue_id IS NULL;
    SQL
  end
end
