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

ActiveRecord::Schema[7.0].define(version: 2023_09_11_072108) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.integer "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "logfiles", force: :cascade do |t|
    t.integer "report_id"
    t.string "ext"
    t.binary "data"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.index ["report_id", "ext"], name: "index_logfiles_on_report_id_and_ext", unique: true
    t.index ["report_id"], name: "index_logfiles_on_report_id"
  end

  create_table "recents", force: :cascade do |t|
    t.string "name", null: false
    t.integer "server_id", null: false
    t.string "etag", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["server_id"], name: "index_recents_on_server_id"
  end

  create_table "reports", force: :cascade do |t|
    t.integer "server_id"
    t.datetime "datetime", precision: nil
    t.string "branch"
    t.integer "revision"
    t.text "summary"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.string "option"
    t.text "ltsv"
    t.index ["branch"], name: "index_reports_on_branch"
    t.index ["datetime"], name: "index_reports_on_datetime"
    t.index ["server_id", "branch", "option"], name: "index_reports_on_server_id_and_branch_and_option"
  end

  create_table "servers", force: :cascade do |t|
    t.string "name"
    t.string "uri"
    t.datetime "created_at", precision: nil
    t.datetime "updated_at", precision: nil
    t.float "ordinal"
    t.index ["name"], name: "index_servers_on_name"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "recents", "servers"
end
