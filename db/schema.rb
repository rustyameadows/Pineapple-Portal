# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_01_27_093001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "approvals", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "title", null: false
    t.text "summary"
    t.text "instructions"
    t.boolean "client_visible", default: false, null: false
    t.string "status", default: "pending", null: false
    t.string "client_name"
    t.text "client_note"
    t.datetime "acknowledged_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "client_visible"], name: "index_approvals_on_event_id_and_client_visible"
    t.index ["event_id", "status"], name: "index_approvals_on_event_id_and_status"
    t.index ["event_id"], name: "index_approvals_on_event_id"
  end

  create_table "attachments", force: :cascade do |t|
    t.string "entity_type", null: false
    t.bigint "entity_id", null: false
    t.bigint "document_id"
    t.uuid "document_logical_id"
    t.string "context", default: "other", null: false
    t.integer "position", default: 1, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_id"], name: "index_attachments_on_document_id"
    t.index ["document_logical_id"], name: "index_attachments_on_document_logical_id"
    t.index ["entity_type", "entity_id", "context", "position"], name: "index_attachments_on_entity_scope", unique: true
    t.index ["entity_type", "entity_id"], name: "index_attachments_on_entity"
    t.check_constraint "context::text = ANY (ARRAY['prompt'::character varying, 'help_text'::character varying, 'answer'::character varying, 'other'::character varying]::text[])", name: "attachments_context_valid"
    t.check_constraint "document_id IS NOT NULL AND document_logical_id IS NULL OR document_id IS NULL AND document_logical_id IS NOT NULL", name: "attachments_exactly_one_document_reference"
  end

  create_table "calendar_item_tags", force: :cascade do |t|
    t.bigint "calendar_item_id", null: false
    t.bigint "event_calendar_tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["calendar_item_id", "event_calendar_tag_id"], name: "index_calendar_item_tags_on_item_and_tag", unique: true
    t.index ["calendar_item_id"], name: "index_calendar_item_tags_on_calendar_item_id"
    t.index ["event_calendar_tag_id"], name: "index_calendar_item_tags_on_event_calendar_tag_id"
  end

  create_table "calendar_item_team_members", force: :cascade do |t|
    t.bigint "calendar_item_id", null: false
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["calendar_item_id", "user_id"], name: "index_calendar_item_team_members_on_item_and_user", unique: true
    t.index ["calendar_item_id"], name: "index_calendar_item_team_members_on_calendar_item_id"
    t.index ["user_id"], name: "index_calendar_item_team_members_on_user_id"
  end

  create_table "calendar_items", force: :cascade do |t|
    t.bigint "event_calendar_id", null: false
    t.string "title", null: false
    t.text "notes"
    t.integer "duration_minutes"
    t.datetime "starts_at"
    t.bigint "relative_anchor_id"
    t.integer "relative_offset_minutes", default: 0, null: false
    t.boolean "relative_before", default: false, null: false
    t.boolean "locked", default: false, null: false
    t.integer "position", default: 0, null: false
    t.string "tag_summary", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "relative_to_anchor_end", default: false, null: false
    t.string "vendor_name"
    t.string "location_name"
    t.string "status", default: "planned", null: false
    t.string "additional_team_members"
    t.string "time_caption"
    t.index ["event_calendar_id", "position"], name: "index_calendar_items_on_calendar_and_position"
    t.index ["event_calendar_id"], name: "index_calendar_items_on_event_calendar_id"
    t.index ["relative_anchor_id"], name: "index_calendar_items_on_relative_anchor_id"
    t.index ["starts_at"], name: "index_calendar_items_on_starts_at"
    t.index ["status"], name: "index_calendar_items_on_status"
    t.check_constraint "duration_minutes IS NULL OR duration_minutes >= 0", name: "calendar_items_duration_non_negative"
    t.check_constraint "relative_offset_minutes IS NOT NULL", name: "calendar_items_relative_offset_present"
  end

  create_table "calendar_template_item_tags", force: :cascade do |t|
    t.bigint "calendar_template_item_id", null: false
    t.bigint "calendar_template_tag_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["calendar_template_item_id", "calendar_template_tag_id"], name: "index_calendar_template_item_tags_on_item_and_tag", unique: true
    t.index ["calendar_template_item_id"], name: "index_calendar_template_item_tags_on_calendar_template_item_id"
    t.index ["calendar_template_tag_id"], name: "index_calendar_template_item_tags_on_calendar_template_tag_id"
  end

  create_table "calendar_template_items", force: :cascade do |t|
    t.bigint "calendar_template_id", null: false
    t.string "title", null: false
    t.text "notes"
    t.integer "duration_minutes"
    t.integer "default_offset_minutes", default: 0, null: false
    t.boolean "default_before", default: false, null: false
    t.boolean "locked_by_default", default: false, null: false
    t.bigint "relative_anchor_template_item_id"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["calendar_template_id", "position"], name: "index_calendar_template_items_on_template_and_position"
    t.index ["calendar_template_id"], name: "index_calendar_template_items_on_calendar_template_id"
    t.check_constraint "duration_minutes IS NULL OR duration_minutes >= 0", name: "calendar_template_items_duration_non_negative"
  end

  create_table "calendar_template_tags", force: :cascade do |t|
    t.bigint "calendar_template_id", null: false
    t.string "name", null: false
    t.string "color_token"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["calendar_template_id", "name"], name: "index_calendar_template_tags_on_template_and_name", unique: true
    t.index ["calendar_template_id"], name: "index_calendar_template_tags_on_calendar_template_id"
  end

  create_table "calendar_template_views", force: :cascade do |t|
    t.bigint "calendar_template_id", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.string "description"
    t.jsonb "tag_filter", default: [], null: false
    t.boolean "hide_locked", default: false, null: false
    t.boolean "client_visible_by_default", default: false, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["calendar_template_id", "slug"], name: "index_calendar_template_views_on_template_and_slug", unique: true
    t.index ["calendar_template_id"], name: "index_calendar_template_views_on_calendar_template_id"
    t.check_constraint "jsonb_typeof(tag_filter) = 'array'::text", name: "calendar_template_views_tag_filter_array"
  end

  create_table "calendar_templates", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "description"
    t.string "default_timezone", default: "UTC", null: false
    t.string "category"
    t.jsonb "variable_definitions", default: {}, null: false
    t.integer "version", default: 1, null: false
    t.boolean "archived", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_calendar_templates_on_slug", unique: true
    t.check_constraint "jsonb_typeof(variable_definitions) = 'object'::text", name: "calendar_templates_variable_definitions_object"
  end

  create_table "document_builds", force: :cascade do |t|
    t.bigint "document_id", null: false
    t.string "status", default: "pending", null: false
    t.string "build_id", null: false
    t.integer "compiled_page_count"
    t.integer "file_size"
    t.string "checksum_sha256"
    t.datetime "started_at"
    t.datetime "finished_at"
    t.string "error_message"
    t.bigint "built_by_user_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["build_id"], name: "index_document_builds_on_build_id", unique: true
    t.index ["built_by_user_id"], name: "index_document_builds_on_built_by_user_id"
    t.index ["document_id"], name: "index_document_builds_on_document_id"
  end

  create_table "document_dependencies", force: :cascade do |t|
    t.uuid "document_logical_id", null: false
    t.bigint "segment_id", null: false
    t.string "entity_type", null: false
    t.bigint "entity_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["document_logical_id"], name: "index_document_dependencies_on_document_logical_id"
    t.index ["entity_type", "entity_id"], name: "index_document_dependencies_on_entity"
  end

  create_table "document_segments", force: :cascade do |t|
    t.uuid "document_logical_id", null: false
    t.integer "position", null: false
    t.string "kind", null: false
    t.string "title", default: "", null: false
    t.jsonb "source_ref", default: {}, null: false
    t.jsonb "spec", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "render_hash"
    t.string "cached_pdf_key"
    t.datetime "cached_pdf_generated_at"
    t.integer "cached_page_count"
    t.integer "cached_file_size"
    t.string "last_render_error"
    t.index ["document_logical_id", "position"], name: "index_document_segments_on_logical_id_and_position", unique: true
    t.index ["document_logical_id"], name: "index_document_segments_on_document_logical_id"
    t.index ["render_hash"], name: "index_document_segments_on_render_hash"
    t.check_constraint "\"position\" > 0", name: "document_segments_position_positive"
  end

  create_table "documents", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "title", null: false
    t.string "storage_uri"
    t.string "checksum"
    t.bigint "size_bytes"
    t.uuid "logical_id", null: false
    t.integer "version", null: false
    t.boolean "is_latest", default: true, null: false
    t.string "content_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "client_visible", default: false, null: false
    t.string "source", default: "staff_upload", null: false
    t.string "doc_kind", default: "uploaded", null: false
    t.boolean "is_template", default: false, null: false
    t.uuid "template_source_logical_id"
    t.bigint "built_by_user_id"
    t.uuid "build_id"
    t.string "manifest_hash"
    t.string "checksum_sha256"
    t.integer "compiled_page_count"
    t.boolean "financial_portal_visible", default: false, null: false
    t.index ["build_id"], name: "index_documents_on_build_id"
    t.index ["client_visible"], name: "index_documents_on_client_visible"
    t.index ["doc_kind"], name: "index_documents_on_doc_kind"
    t.index ["event_id"], name: "index_documents_on_event_id"
    t.index ["logical_id", "version"], name: "index_documents_on_logical_id_and_version", unique: true
    t.index ["logical_id"], name: "index_documents_on_logical_id_latest", unique: true, where: "(is_latest = true)"
    t.index ["source"], name: "index_documents_on_source"
    t.index ["template_source_logical_id"], name: "index_documents_on_template_source_logical_id"
    t.check_constraint "size_bytes > 0", name: "documents_size_positive"
    t.check_constraint "version > 0", name: "documents_version_positive"
  end

  create_table "event_calendar_tags", force: :cascade do |t|
    t.bigint "event_calendar_id", null: false
    t.string "name", null: false
    t.string "color_token"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_calendar_id", "name"], name: "index_event_calendar_tags_on_calendar_and_name", unique: true
    t.index ["event_calendar_id"], name: "index_event_calendar_tags_on_event_calendar_id"
  end

  create_table "event_calendar_views", force: :cascade do |t|
    t.bigint "event_calendar_id", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.string "description"
    t.jsonb "tag_filter", default: [], null: false
    t.boolean "hide_locked", default: false, null: false
    t.boolean "client_visible", default: false, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_calendar_id", "slug"], name: "index_event_calendar_views_on_calendar_and_slug", unique: true
    t.index ["event_calendar_id"], name: "index_event_calendar_views_on_event_calendar_id"
    t.check_constraint "jsonb_typeof(tag_filter) = 'array'::text", name: "event_calendar_views_tag_filter_array"
  end

  create_table "event_calendars", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.string "description"
    t.string "timezone", default: "America/New_York", null: false
    t.string "kind", default: "master", null: false
    t.boolean "client_visible", default: false, null: false
    t.bigint "template_source_id"
    t.integer "position", default: 0, null: false
    t.integer "template_version"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "slug"], name: "index_event_calendars_on_event_id_and_slug", unique: true
    t.index ["event_id"], name: "index_event_calendars_on_event_id"
    t.index ["event_id"], name: "index_event_calendars_on_event_id_and_master", unique: true, where: "((kind)::text = 'master'::text)"
    t.index ["kind"], name: "index_event_calendars_on_kind"
    t.index ["template_source_id"], name: "index_event_calendars_on_template_source_id"
    t.check_constraint "kind::text = ANY (ARRAY['master'::character varying, 'derived'::character varying]::text[])", name: "event_calendars_kind_check"
  end

  create_table "event_links", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "label", null: false
    t.string "url", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "link_type", default: "quick", null: false
    t.boolean "financial_only", default: false, null: false
    t.index ["event_id", "link_type"], name: "index_event_links_on_event_id_and_link_type"
    t.index ["event_id", "position"], name: "index_event_links_on_event_id_and_position"
    t.index ["event_id"], name: "index_event_links_on_event_id"
  end

  create_table "event_team_members", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.bigint "user_id", null: false
    t.boolean "client_visible", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "lead_planner", default: false, null: false
    t.integer "position", default: 0, null: false
    t.string "member_role", default: "planner", null: false
    t.index ["client_visible"], name: "index_event_team_members_on_client_visible"
    t.index ["event_id", "position"], name: "index_event_team_members_on_event_id_and_position"
    t.index ["event_id", "user_id"], name: "index_event_team_members_on_event_id_and_user_id", unique: true
    t.index ["event_id"], name: "index_event_team_members_on_event_id"
    t.index ["lead_planner"], name: "index_event_team_members_on_lead_planner"
    t.index ["member_role"], name: "index_event_team_members_on_member_role"
    t.index ["user_id"], name: "index_event_team_members_on_user_id"
  end

  create_table "event_vendors", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "name", null: false
    t.jsonb "contacts_jsonb", default: [], null: false
    t.integer "position", default: 0, null: false
    t.boolean "client_visible", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "vendor_type"
    t.string "social_handle"
    t.index "event_id, lower((name)::text)", name: "index_event_vendors_on_event_id_and_lower_name", unique: true
    t.index ["event_id", "position"], name: "index_event_vendors_on_event_id_and_position"
    t.index ["event_id"], name: "index_event_vendors_on_event_id"
    t.check_constraint "jsonb_typeof(contacts_jsonb) = 'array'::text", name: "event_vendors_contacts_jsonb_array"
  end

  create_table "event_venues", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "name", null: false
    t.jsonb "contacts_jsonb", default: [], null: false
    t.integer "position", default: 0, null: false
    t.boolean "client_visible", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index "event_id, lower((name)::text)", name: "index_event_venues_on_event_id_and_lower_name", unique: true
    t.index ["event_id", "position"], name: "index_event_venues_on_event_id_and_position"
    t.index ["event_id"], name: "index_event_venues_on_event_id"
    t.check_constraint "jsonb_typeof(contacts_jsonb) = 'array'::text", name: "event_venues_contacts_jsonb_array"
  end

  create_table "events", force: :cascade do |t|
    t.string "name", null: false
    t.date "starts_on"
    t.date "ends_on"
    t.string "location"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "archived_at"
    t.bigint "event_photo_document_id"
    t.jsonb "planning_link_keys", default: [], null: false
    t.string "location_secondary"
    t.boolean "financial_payments_enabled", default: false, null: false
    t.string "portal_slug"
    t.index ["archived_at"], name: "index_events_on_archived_at"
    t.index ["event_photo_document_id"], name: "index_events_on_event_photo_document_id"
    t.index ["name"], name: "index_events_on_name"
    t.index ["portal_slug"], name: "index_events_on_portal_slug", unique: true
    t.check_constraint "jsonb_typeof(planning_link_keys) = 'array'::text", name: "events_planning_link_keys_array"
  end

  create_table "global_assets", force: :cascade do |t|
    t.string "storage_uri", null: false
    t.string "filename", null: false
    t.string "content_type", null: false
    t.bigint "size_bytes"
    t.string "checksum"
    t.string "label"
    t.bigint "uploaded_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["storage_uri"], name: "index_global_assets_on_storage_uri", unique: true
    t.index ["uploaded_by_id"], name: "index_global_assets_on_uploaded_by_id"
  end

  create_table "password_reset_tokens", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "issued_by_id"
    t.string "token", null: false
    t.datetime "expires_at", null: false
    t.datetime "redeemed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_password_reset_tokens_on_expires_at"
    t.index ["issued_by_id"], name: "index_password_reset_tokens_on_issued_by_id"
    t.index ["token"], name: "index_password_reset_tokens_on_token", unique: true
    t.index ["user_id"], name: "index_password_reset_tokens_on_user_id"
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "title", null: false
    t.decimal "amount", precision: 12, scale: 2, default: "0.0", null: false
    t.date "due_on"
    t.text "description"
    t.boolean "client_visible", default: false, null: false
    t.string "status", default: "pending", null: false
    t.datetime "paid_at"
    t.datetime "paid_by_client_at"
    t.text "client_note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "due_on"], name: "index_payments_on_event_id_and_due_on"
    t.index ["event_id", "status"], name: "index_payments_on_event_id_and_status"
    t.index ["event_id"], name: "index_payments_on_event_id"
  end

  create_table "questionnaire_sections", force: :cascade do |t|
    t.bigint "questionnaire_id", null: false
    t.string "title", null: false
    t.text "helper_text"
    t.integer "position", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["questionnaire_id", "position"], name: "index_questionnaire_sections_on_questionnaire_id_and_position"
    t.index ["questionnaire_id"], name: "index_questionnaire_sections_on_questionnaire_id"
  end

  create_table "questionnaires", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "title", null: false
    t.text "description"
    t.boolean "is_template", default: false, null: false
    t.bigint "template_source_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "client_visible", default: false, null: false
    t.string "status", default: "in_progress", null: false
    t.index ["client_visible"], name: "index_questionnaires_on_client_visible"
    t.index ["event_id", "template_source_id"], name: "index_questionnaires_on_event_id_and_template_source_id", unique: true, where: "(template_source_id IS NOT NULL)"
    t.index ["event_id"], name: "index_questionnaires_on_event_id"
    t.index ["is_template"], name: "index_questionnaires_on_is_template"
    t.index ["status"], name: "index_questionnaires_on_status"
    t.index ["template_source_id"], name: "index_questionnaires_on_template_source_id"
  end

  create_table "questions", force: :cascade do |t|
    t.bigint "questionnaire_id", null: false
    t.bigint "event_id", null: false
    t.text "prompt", null: false
    t.text "help_text"
    t.string "response_type", default: "text", null: false
    t.integer "position", default: 1, null: false
    t.text "answer_value"
    t.jsonb "answer_raw", default: {}
    t.datetime "answered_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "questionnaire_section_id", null: false
    t.index ["event_id"], name: "index_questions_on_event_id"
    t.index ["questionnaire_id", "position"], name: "index_questions_on_questionnaire_id_and_position"
    t.index ["questionnaire_id"], name: "index_questions_on_questionnaire_id"
    t.index ["questionnaire_section_id"], name: "index_questions_on_questionnaire_section_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "password_digest"
    t.string "role", default: "planner", null: false
    t.string "title"
    t.string "phone_number"
    t.bigint "avatar_global_asset_id"
    t.string "account_kind", default: "account", null: false
    t.text "general_notes"
    t.text "dietary_restrictions"
    t.boolean "can_view_financials", default: false, null: false
    t.index ["account_kind"], name: "index_users_on_account_kind"
    t.index ["avatar_global_asset_id"], name: "index_users_on_avatar_global_asset_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "approvals", "events"
  add_foreign_key "attachments", "documents"
  add_foreign_key "calendar_item_tags", "calendar_items", on_delete: :cascade
  add_foreign_key "calendar_item_tags", "event_calendar_tags", on_delete: :cascade
  add_foreign_key "calendar_item_team_members", "calendar_items"
  add_foreign_key "calendar_item_team_members", "users"
  add_foreign_key "calendar_items", "calendar_items", column: "relative_anchor_id", on_delete: :nullify
  add_foreign_key "calendar_items", "event_calendars", on_delete: :cascade
  add_foreign_key "calendar_template_item_tags", "calendar_template_items", on_delete: :cascade
  add_foreign_key "calendar_template_item_tags", "calendar_template_tags", on_delete: :cascade
  add_foreign_key "calendar_template_items", "calendar_template_items", column: "relative_anchor_template_item_id", on_delete: :nullify
  add_foreign_key "calendar_template_items", "calendar_templates", on_delete: :cascade
  add_foreign_key "calendar_template_tags", "calendar_templates", on_delete: :cascade
  add_foreign_key "calendar_template_views", "calendar_templates", on_delete: :cascade
  add_foreign_key "document_builds", "documents"
  add_foreign_key "document_builds", "users", column: "built_by_user_id"
  add_foreign_key "document_dependencies", "document_segments", column: "segment_id", on_delete: :cascade
  add_foreign_key "documents", "events"
  add_foreign_key "documents", "users", column: "built_by_user_id"
  add_foreign_key "event_calendar_tags", "event_calendars", on_delete: :cascade
  add_foreign_key "event_calendar_views", "event_calendars", on_delete: :cascade
  add_foreign_key "event_calendars", "calendar_templates", column: "template_source_id", on_delete: :nullify
  add_foreign_key "event_calendars", "events"
  add_foreign_key "event_links", "events"
  add_foreign_key "event_team_members", "events"
  add_foreign_key "event_team_members", "users"
  add_foreign_key "event_vendors", "events"
  add_foreign_key "event_venues", "events"
  add_foreign_key "events", "documents", column: "event_photo_document_id"
  add_foreign_key "global_assets", "users", column: "uploaded_by_id"
  add_foreign_key "password_reset_tokens", "users"
  add_foreign_key "password_reset_tokens", "users", column: "issued_by_id"
  add_foreign_key "payments", "events"
  add_foreign_key "questionnaire_sections", "questionnaires"
  add_foreign_key "questionnaires", "events"
  add_foreign_key "questionnaires", "questionnaires", column: "template_source_id"
  add_foreign_key "questions", "events"
  add_foreign_key "questions", "questionnaire_sections"
  add_foreign_key "questions", "questionnaires"
  add_foreign_key "users", "global_assets", column: "avatar_global_asset_id"
end
