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

ActiveRecord::Schema[8.0].define(version: 2026_02_20_155508) do
  create_table "action_items", force: :cascade do |t|
    t.integer "summary_id", null: false
    t.text "source_type"
    t.integer "source_id"
    t.text "description", null: false
    t.text "assignee_user_id"
    t.text "source_ts"
    t.text "status", default: "open", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "priority", default: 3, null: false
    t.index ["source_type", "source_id"], name: "index_action_items_on_source_type_and_source_id"
    t.index ["status"], name: "index_action_items_on_status"
    t.index ["summary_id"], name: "index_action_items_on_summary_id"
  end

  create_table "live_activities", force: :cascade do |t|
    t.text "activity_id", null: false
    t.text "activity_type", null: false
    t.text "title", null: false
    t.text "subtitle"
    t.text "status", default: "active", null: false
    t.json "metadata", default: {}
    t.datetime "ends_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["activity_type", "activity_id"], name: "index_live_activities_on_activity_type_and_activity_id", unique: true
  end

  create_table "slack_channels", force: :cascade do |t|
    t.integer "workspace_id", null: false
    t.text "channel_id", null: false
    t.text "channel_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "hidden", default: false, null: false
    t.integer "priority", default: 3, null: false
    t.text "interaction_description"
    t.boolean "actionable", default: true, null: false
    t.integer "predecessor_id"
    t.index ["predecessor_id"], name: "index_slack_channels_on_predecessor_id"
    t.index ["workspace_id", "channel_id"], name: "index_slack_channels_on_workspace_id_and_channel_id", unique: true
    t.index ["workspace_id"], name: "index_slack_channels_on_workspace_id"
  end

  create_table "slack_events", force: :cascade do |t|
    t.integer "slack_channel_id", null: false
    t.text "event_id", null: false
    t.text "event_type"
    t.text "user_id"
    t.text "ts"
    t.text "thread_ts"
    t.json "payload"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_slack_events_on_event_id", unique: true
    t.index ["slack_channel_id", "created_at"], name: "index_slack_events_on_slack_channel_id_and_created_at"
    t.index ["slack_channel_id"], name: "index_slack_events_on_slack_channel_id"
  end

  create_table "summaries", force: :cascade do |t|
    t.text "source_type"
    t.integer "source_id"
    t.datetime "period_start"
    t.datetime "period_end"
    t.text "summary_text"
    t.text "model_used"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["source_type", "source_id"], name: "index_summaries_on_source_type_and_source_id"
  end

  create_table "workspaces", force: :cascade do |t|
    t.text "team_name"
    t.text "user_token"
    t.text "signing_secret"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "include_dms", default: false, null: false
    t.boolean "include_mpims", default: false, null: false
    t.text "team_id"
  end

  add_foreign_key "action_items", "summaries"
  add_foreign_key "slack_channels", "slack_channels", column: "predecessor_id"
  add_foreign_key "slack_channels", "workspaces"
  add_foreign_key "slack_events", "slack_channels"
end
