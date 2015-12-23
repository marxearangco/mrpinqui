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

ActiveRecord::Schema.define(version: 20151116091036) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "images", force: true do |t|
    t.integer  "code"
    t.string   "photo_file_name"
    t.string   "photo_content_type"
    t.integer  "photo_file_size"
    t.datetime "photo_updated_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "branch"
  end

  create_table "tblempauth", force: true do |t|
    t.integer "employee_id"
    t.integer "idEmp"
    t.string  "userName"
    t.string  "passWord"
    t.integer "privilege_id"
    t.string  "branch"
  end

  add_index "tblempauth", ["privilege_id"], name: "index_tblempauth_on_privilege_id", using: :btree

  create_table "tblemployee", force: true do |t|
    t.integer "employee_id"
    t.integer "idEmp"
    t.string  "fName",       limit: 25
    t.string  "midInit",     limit: 2
    t.string  "lName",       limit: 25
    t.integer "idPosition",             null: false
    t.integer "idCmpny",                null: false
    t.string  "empStatus",   limit: 20
    t.string  "branch"
  end

  create_table "tblitem", force: true do |t|
    t.integer "idItem"
    t.integer "idSupplier"
    t.integer "brand_id"
    t.string  "itemname",     limit: 100
    t.text    "detail"
    t.integer "category_id"
    t.integer "idUnit"
    t.integer "code"
    t.string  "barcode",      limit: 10
    t.float   "cost"
    t.float   "sellingPrice"
    t.integer "begBalance",               null: false
    t.date    "dateInput"
    t.integer "percent"
    t.float   "dealerPrice"
    t.date    "dateUpdated"
    t.string  "itemStatus",   limit: 20
    t.integer "idLocation"
    t.string  "partNum",      limit: 20
    t.string  "bikeModel",    limit: 100
    t.string  "vin",          limit: 15
    t.integer "idSkRm"
    t.string  "branch"
  end
  add_index "tblitem", ["category_id"], name: "index_tblitemcategory_on_category_id", using: :btree
  add_index "tblitem", ["brand_id"], name: "index_tblitembrand_on_category_id", using: :btree

  create_table "tblitembrand", force: true do |t|
    t.integer "brand_id"
    t.string  "brandname"
    t.integer "category_id", null: false
    t.string  "branch"
  end
  add_index "tblitembrand", ["category_id"], name: "index_Brand_on_Category", using: :btree

  create_table "tblitemcategory", force: true do |t|
    t.integer "category_id"
    t.string  "category"
    t.string  "branch"
  end

  create_table "tbllocation", force: true do |t|
    t.integer "idLocation"
    t.string  "locationCode"
    t.string  "location"
  end

  create_table "tblprivilege", force: true do |t|
    t.string "privilege"
  end

  create_table "tblinventory", force: true do |t|
    t.integer "inventory_id"
    t.integer "code"
    t.integer "qtyBeg"
    t.integer "qtyIn"
    t.integer "qtyOut"
    t.integer "qtyEnd"
    t.string  "remarks"
    t.date    "dateInv"
    t.float   "srp"
    t.float   "cost"
    t.string  "branch"
  end

  create_table "tblitemvin", force: true do |t|
    t.string  "vin"
    t.integer "idSkRm"
    t.string  "branch"
  end
end
