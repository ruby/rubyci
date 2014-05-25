# encoding: UTF-8
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

ActiveRecord::Schema.define(version: 20140525060954) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "logfiles", force: true do |t|
    t.integer  "report_id"
    t.string   "ext"
    t.binary   "data"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "logfiles", ["report_id", "ext"], name: "index_logfiles_on_report_id_and_ext", unique: true, using: :btree
  add_index "logfiles", ["report_id"], name: "index_logfiles_on_report_id", using: :btree

  create_table "reports", force: true do |t|
    t.integer  "server_id"
    t.datetime "datetime"
    t.string   "branch"
    t.integer  "revision"
    t.text     "summary"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "option"
    t.text     "ltsv"
  end

  add_index "reports", ["branch"], name: "index_reports_on_branch", using: :btree
  add_index "reports", ["datetime"], name: "index_reports_on_datetime", using: :btree
  add_index "reports", ["server_id", "branch"], name: "index_reports_on_server_id_and_branch", using: :btree

  create_table "servers", force: true do |t|
    t.string   "name"
    t.string   "uri"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "arch"
    t.string   "os"
    t.string   "version"
    t.float    "ordinal"
  end

  add_index "servers", ["name"], name: "index_servers_on_name", using: :btree

end
