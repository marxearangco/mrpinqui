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
  end

  create_table "tblempauth", id: false, force: true do |t|
    t.integer "id",                   null: false
    t.integer "idEmp"
    t.string  "userName",  limit: 15
    t.string  "passWord",  limit: 50
    t.integer "privilege"
  end

  create_table "tblemployee", id: false, force: true do |t|
    t.integer "idEmp",                 default: 0, null: false
    t.string  "fName",      limit: 25
    t.string  "midInit",    limit: 2
    t.string  "lName",      limit: 25
    t.integer "idPosition",                        null: false
    t.integer "idCmpny",                           null: false
    t.string  "empStatus",  limit: 20
  end

  create_table "tblinventory", force: true do |t|
    t.integer "code"
    t.integer "qtyBeg"
    t.integer "qtyIn"
    t.integer "qtyOut"
    t.integer "qtyEnd"
    t.text    "remarks"
    t.date    "dateInv"
    t.float   "srp"
    t.float   "cost"
  end

  create_table "tblitem", primary_key: "idItem", force: true do |t|
    t.integer "idSupplier"
    t.integer "idBrand"
    t.string  "itemName",     limit: 250
    t.text    "detail"
    t.integer "idCategory"
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
    t.text    "bikeModel"
    t.string  "vin",          limit: 15
    t.integer "idSkRm"
  end

  create_table "tblitembrand", id: false, force: true do |t|
    t.integer "idBrand",                default: 0, null: false
    t.string  "brandName",  limit: 100
    t.integer "idCategory",                         null: false
  end

  create_table "tblitemcategory", id: false, force: true do |t|
    t.integer "idCategory",            default: 0, null: false
    t.string  "Category",   limit: 60
  end

  create_table "tbllocation", id: false, force: true do |t|
    t.integer "idLocation",               default: 0, null: false
    t.string  "locationCode", limit: 10
    t.string  "Location",     limit: 100
  end

  create_table "tblprivilege", id: false, force: true do |t|
    t.integer "id"
    t.string  "privilege", limit: 50
  end
end
