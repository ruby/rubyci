# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20140227115154) do

  create_table "logfiles", force: :cascade do |t|
    t.integer  "report_id"
    t.string   "ext"
    t.binary   "data"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["report_id", "ext"], name: "index_logfiles_on_report_id_and_ext", unique: true
    t.index ["report_id"], name: "index_logfiles_on_report_id"
  end

  create_table "reports", force: :cascade do |t|
    t.integer  "server_id"
    t.datetime "datetime"
    t.string   "branch"
    t.integer  "revision"
    t.text     "summary"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "option"
    t.text     "ltsv"
    t.index ["branch"], name: "index_reports_on_branch"
    t.index ["datetime"], name: "index_reports_on_datetime"
    t.index ["server_id", "branch"], name: "index_reports_on_server_id_and_branch"
  end

  create_table "servers", force: :cascade do |t|
    t.string   "name"
    t.string   "uri"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "arch"
    t.string   "os"
    t.string   "version"
    t.float    "ordinal"
    t.index ["name"], name: "index_servers_on_name"
  end

end
