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

ActiveRecord::Schema[8.1].define(version: 2026_10_21_144123) do
  create_table "push_subscriptions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "endpoint", null: false
    t.string "p256dh_key", null: false
    t.string "auth_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["endpoint"], name: "index_push_subscriptions_on_endpoint", unique: true
    t.index ["user_id"], name: "index_push_subscriptions_on_user_id"
  end

  create_table "reminders", force: :cascade do |t|
    t.string "note_path", null: false
    t.string "line", null: false
    t.string "directive", null: false
    t.datetime "remind_at"
    t.datetime "notified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "heading"
    t.datetime "missing_since"
    t.datetime "completed_at"
    t.text "notes"
    t.index ["note_path", "line", "directive"], name: "index_reminders_on_note_path_and_line_and_directive", unique: true
    t.index ["remind_at"], name: "index_reminders_on_remind_at"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "note_folders", default: [], null: false
    t.boolean "show_today_only", default: false, null: false
    t.integer "overdue_after_hours", default: 24, null: false
    t.string "reminders_note"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "push_subscriptions", "users"
  add_foreign_key "sessions", "users"
end
