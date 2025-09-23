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

ActiveRecord::Schema[8.0].define(version: 2025_09_23_010000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  create_table "documents", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "title", null: false
    t.string "storage_uri", null: false
    t.string "checksum", null: false
    t.bigint "size_bytes", null: false
    t.uuid "logical_id", null: false
    t.integer "version", null: false
    t.boolean "is_latest", default: true, null: false
    t.string "content_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "client_visible", default: false, null: false
    t.index ["client_visible"], name: "index_documents_on_client_visible"
    t.index ["event_id"], name: "index_documents_on_event_id"
    t.index ["logical_id", "version"], name: "index_documents_on_logical_id_and_version", unique: true
    t.index ["logical_id"], name: "index_documents_on_logical_id_latest", unique: true, where: "(is_latest = true)"
    t.check_constraint "size_bytes > 0", name: "documents_size_positive"
    t.check_constraint "version > 0", name: "documents_version_positive"
  end

  create_table "event_links", force: :cascade do |t|
    t.bigint "event_id", null: false
    t.string "label", null: false
    t.string "url", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id", "position"], name: "index_event_links_on_event_id_and_position"
    t.index ["event_id"], name: "index_event_links_on_event_id"
  end

  create_table "events", force: :cascade do |t|
    t.string "name", null: false
    t.date "starts_on"
    t.date "ends_on"
    t.string "location"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "archived_at"
    t.index ["archived_at"], name: "index_events_on_archived_at"
    t.index ["name"], name: "index_events_on_name"
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
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "attachments", "documents"
  add_foreign_key "documents", "events"
  add_foreign_key "event_links", "events"
  add_foreign_key "questionnaire_sections", "questionnaires"
  add_foreign_key "questionnaires", "events"
  add_foreign_key "questionnaires", "questionnaires", column: "template_source_id"
  add_foreign_key "questions", "events"
  add_foreign_key "questions", "questionnaire_sections"
  add_foreign_key "questions", "questionnaires"
end
