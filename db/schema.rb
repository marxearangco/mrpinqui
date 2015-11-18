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

  create_table "sample", id: false, force: true do |t|
    t.integer "id"
    t.string  "sample", limit: 50
  end

  create_table "tblbikemodels", id: false, force: true do |t|
    t.integer "idBrand"
    t.integer "idModel",              default: 0, null: false
    t.string  "model",   limit: 250
    t.string  "details", limit: 1000
  end

  create_table "tblcharges", id: false, force: true do |t|
    t.integer "idCharges"
    t.string  "charges",   limit: 25
  end

  create_table "tblcity", id: false, force: true do |t|
    t.string "city",      limit: 50
    t.string "provinces", limit: 50
  end

  create_table "tblcompany", id: false, force: true do |t|
    t.integer "idCmpny"
    t.string  "company",  limit: 100
    t.string  "detail",   limit: 200
    t.string  "address1", limit: 150
    t.string  "address2", limit: 150
    t.string  "TIN",      limit: 20
    t.string  "phoneNum", limit: 15
    t.string  "faxNum",   limit: 15
    t.string  "website",  limit: 50
  end

  create_table "tblcourier", id: false, force: true do |t|
    t.integer "idCourier",             default: 0, null: false
    t.string  "courier",   limit: 50
    t.string  "details",   limit: 200
    t.string  "address",   limit: 400
    t.string  "telNum",    limit: 15
    t.string  "faxNum",    limit: 15
    t.string  "website",   limit: 50
  end

  create_table "tblcustomer", id: false, force: true do |t|
    t.integer "idCustomer",               default: 0, null: false
    t.string  "fName",        limit: 50
    t.string  "midInit",      limit: 2
    t.string  "lName",        limit: 50
    t.string  "address",      limit: 250
    t.string  "phonenum",     limit: 20
    t.string  "emailAddress", limit: 50
    t.string  "landlinenum",  limit: 13
    t.date    "birthdate"
    t.string  "city",         limit: 50
    t.string  "province",     limit: 50
    t.string  "region",       limit: 20
    t.string  "tin",          limit: 50
  end

  create_table "tblcustomerbikes", id: false, force: true do |t|
    t.integer "idCustBike"
    t.string  "model",       limit: 100
    t.integer "yearMake"
    t.string  "color",       limit: 25
    t.string  "chassisNo",   limit: 30
    t.string  "plateNo",     limit: 15
    t.string  "engineNo",    limit: 30
    t.string  "orcrNo",      limit: 30
    t.string  "ccDisp",      limit: 30
    t.string  "insurance",   limit: 50
    t.string  "otherInsur",  limit: 50
    t.date    "dateExpiry"
    t.date    "dateAdded"
    t.text    "remarks"
    t.date    "dateUpdated"
    t.integer "idBrand"
    t.integer "idCustomer"
  end

  create_table "tblcustomerservicing", id: false, force: true do |t|
    t.integer "idServicing",             default: 0, null: false
    t.string  "serviceNo",   limit: 15
    t.integer "idCustomer"
    t.integer "idItem"
    t.string  "barcode"
    t.date    "dateTrans"
    t.integer "InCharge"
    t.string  "remarks",     limit: 500
  end

  create_table "tbldeliveries", id: false, force: true do |t|
    t.integer "idDel",                 default: 0,  null: false
    t.integer "idOrder"
    t.integer "pk"
    t.string  "toBranch",   limit: 25
    t.string  "fromBranch", limit: 25
    t.string  "poidBranch", limit: 16
    t.string  "toInchrg",   limit: 30
    t.text    "toLctn"
    t.string  "rcptNo",     limit: 15
    t.string  "rcptBy",     limit: 30
    t.string  "termDel",    limit: 15
    t.date    "dateDue"
    t.string  "invcNo",     limit: 15
    t.string  "docNo",      limit: 15, default: ""
    t.string  "refNo",      limit: 15
    t.string  "soldTo",     limit: 30
    t.integer "totalQty"
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

  create_table "tblempstatus", id: false, force: true do |t|
    t.string "empStatus", limit: 50
  end

  create_table "tblinsurance", id: false, force: true do |t|
    t.string "insurance", limit: 20
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

  create_table "tblitembarcode", id: false, force: true do |t|
    t.integer "idBarcode"
    t.integer "pk",          limit: 8,  null: false
    t.string  "itemBarcode", limit: 25, null: false
    t.integer "idOrder",                null: false
    t.integer "idItem",                 null: false
    t.integer "idSales",                null: false
  end

  create_table "tblitembegcost", id: false, force: true do |t|
    t.integer "idItem"
    t.integer "code"
    t.float   "cost"
    t.integer "begBalance"
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

  create_table "tblitemhistory", primary_key: "idHistory", force: true do |t|
    t.date    "transDate"
    t.integer "transID"
    t.string  "transNo",    limit: 15
    t.string  "transDesc",  limit: 50
    t.integer "code"
    t.integer "qtyBeg"
    t.integer "qtyIn"
    t.integer "qtyOut"
    t.integer "qtyEnd"
    t.float   "amount"
    t.string  "unit",       limit: 20
    t.integer "idCategory"
    t.integer "idBrand"
    t.integer "idSupplier"
    t.string  "remarks",    limit: 250
    t.string  "status",     limit: 50
    t.string  "partNum",    limit: 50
    t.string  "transby",    limit: 50
  end

  create_table "tblitemlocation", id: false, force: true do |t|
    t.integer "idIL",                        null: false
    t.integer "pk"
    t.integer "idItem"
    t.string  "code",            limit: 25
    t.integer "location"
    t.string  "locationDetails", limit: 300
    t.string  "owner",           limit: 50
    t.string  "status",          limit: 100
    t.string  "remarks",         limit: 500
    t.integer "updatedBy"
    t.date    "dateUpdated"
    t.integer "certifiedBy"
  end

  create_table "tblitemmaintenance", id: false, force: true do |t|
    t.integer "idim",                      default: 0, null: false
    t.string  "serviceNo",      limit: 15
    t.integer "idCustomer",                            null: false
    t.date    "dateReceived",                          null: false
    t.string  "receivedBy",     limit: 25,             null: false
    t.string  "location",       limit: 10
    t.integer "services",                              null: false
    t.text    "details",                               null: false
    t.date    "dateMaintained",                        null: false
    t.string  "maintainedBy",   limit: 50,             null: false
    t.float   "serviceCost",                           null: false
    t.string  "itemStatus",     limit: 30,             null: false
    t.text    "itemRemarks",                           null: false
    t.string  "checkedBy",      limit: 50,             null: false
    t.date    "dateReleased",                          null: false
    t.string  "releasedBy",     limit: 50,             null: false
    t.integer "idMtrbikes"
    t.integer "idCustBike"
  end

  create_table "tblitemstatus", id: false, force: true do |t|
    t.string "itemStatus"
  end

  create_table "tblitemtax", id: false, force: true do |t|
    t.integer "idVat",              default: 0, null: false
    t.string  "tax",     limit: 25
    t.integer "percent",                        null: false
  end

  create_table "tblitemvin", id: false, force: true do |t|
    t.string  "vin",    limit: 15
    t.integer "idSkRm"
  end

  create_table "tbljoborder", id: false, force: true do |t|
    t.integer "idJO",                      default: 0, null: false
    t.integer "idCustomer"
    t.string  "clNo",         limit: 15
    t.date    "dateStarted"
    t.integer "idMtrbikes"
    t.integer "idCustBike"
    t.string  "batteryNo",    limit: 20
    t.string  "odometer",     limit: 20
    t.integer "idBrand"
    t.integer "idModel"
    t.string  "service",      limit: 1000
    t.integer "idSrvcType"
    t.string  "code",         limit: 20
    t.integer "idSrvcTime"
    t.integer "idSrvCC"
    t.integer "minutes"
    t.float   "flatRate"
    t.text    "joRmrks"
    t.string  "joRcvdBy",     limit: 30
    t.string  "joPrprdBy",    limit: 30
    t.string  "joChckdBy",    limit: 30
    t.string  "joApprvdBy",   limit: 30
    t.string  "joid",         limit: 10
    t.string  "jeid",         limit: 30
    t.date    "dateFinished"
    t.string  "timeIn",       limit: 10
    t.string  "timeOut",      limit: 10
    t.string  "jePrprdBy",    limit: 30
    t.string  "jeNotedBy",    limit: 30
    t.string  "jeApprvdBy",   limit: 30
    t.string  "status",       limit: 15
    t.string  "jeRmrks",      limit: 1000
    t.string  "soID",         limit: 15
    t.string  "salesInvc",    limit: 15
    t.string  "salesOr",      limit: 15
    t.string  "payMode",      limit: 50
    t.string  "checkNo",      limit: 50
    t.float   "partsTotal"
    t.float   "partDscnt"
    t.float   "srvcTotal"
    t.float   "srvcDscnt"
    t.float   "grandTotal"
  end

  create_table "tbljoitems", id: false, force: true do |t|
    t.integer "idJOI",                 default: 0, null: false
    t.integer "idItem"
    t.integer "idSrvcItem"
    t.string  "unit",       limit: 10
    t.integer "qty"
    t.float   "unitPrice"
    t.integer "discount"
    t.float   "amntDscnt"
    t.float   "amount"
    t.string  "status",     limit: 20
    t.text    "remarks"
    t.integer "idJO"
    t.string  "joID",       limit: 15
  end

  create_table "tbljoservices", force: true do |t|
    t.integer "idJO"
    t.string  "joID",        limit: 15
    t.integer "idSrvcTime"
    t.integer "idSrvcOther"
    t.string  "services",    limit: 1000
    t.decimal "minutes",                  precision: 10, scale: 2
    t.integer "qty"
    t.float   "charge"
    t.string  "bikeBrand",   limit: 50
  end

  create_table "tbllocation", id: false, force: true do |t|
    t.integer "idLocation",               default: 0, null: false
    t.string  "locationCode", limit: 10
    t.string  "Location",     limit: 100
  end

  create_table "tblmotorbikes", id: false, force: true do |t|
    t.integer "idMtrbikes"
    t.integer "idItem"
    t.string  "model",       limit: 100
    t.integer "yearMake"
    t.string  "color",       limit: 30
    t.string  "chassisNo",   limit: 80
    t.string  "plateNo",     limit: 30
    t.string  "engineNo",    limit: 30
    t.string  "orcrNo",      limit: 30
    t.string  "ccDisp",      limit: 100
    t.string  "vin",         limit: 30
    t.string  "insurance",   limit: 20
    t.string  "otherInsur",  limit: 20
    t.date    "dateExpiry"
    t.date    "dateAdded"
    t.date    "dateUpdated"
    t.string  "type",        limit: 30
    t.string  "status",      limit: 30
    t.text    "remarks"
    t.string  "stockLctn",   limit: 30
  end

  create_table "tblorder", id: false, force: true do |t|
    t.integer "idOrder",                     default: 0, null: false
    t.integer "idSupplier"
    t.date    "dateOrdered"
    t.date    "deliveryDate"
    t.integer "requestBy"
    t.string  "transtype",        limit: 15
    t.integer "term"
    t.string  "orderStatus",      limit: 15
    t.string  "paymentStatus",    limit: 15
    t.date    "dateReceived"
    t.string  "receivedBy",       limit: 70
    t.text    "receivingRemarks"
    t.string  "poID",             limit: 16,             null: false
    t.string  "roID",             limit: 16,             null: false
    t.string  "checkedBy",        limit: 70
    t.string  "courier",          limit: 50
    t.string  "poChecker",        limit: 30
    t.string  "poApproval",       limit: 30
    t.integer "shipTo"
    t.integer "shipVia"
    t.integer "idMode"
    t.integer "idTerm"
    t.string  "checkNo",          limit: 20
    t.string  "rcptNo",           limit: 20
    t.string  "paymentMode",      limit: 50
    t.string  "paymentType",      limit: 50
  end

  create_table "tblordereditems", primary_key: "pk", force: true do |t|
    t.integer "idOrder"
    t.integer "idItem"
    t.integer "quantity",                  null: false
    t.integer "idUnit"
    t.float   "cost"
    t.integer "balance"
    t.string  "status",        limit: 15
    t.integer "qtypending",                null: false
    t.integer "qtyreceived",               null: false
    t.integer "qtyreturned",               null: false
    t.string  "returnRemarks", limit: 100, null: false
    t.date    "dateReceived"
    t.float   "srp"
    t.float   "dealerPrice"
    t.string  "remarks",       limit: 30
    t.string  "roID",          limit: 15
    t.string  "taxStatus",     limit: 25
    t.integer "idSupplier"
  end

  create_table "tblorderreturn", id: false, force: true do |t|
    t.integer "idReturn",        null: false
    t.integer "idOrder"
    t.date    "dateReturn"
    t.integer "processedReturn"
  end

  create_table "tblorderreturnitems", id: false, force: true do |t|
    t.integer "id",       default: 0, null: false
    t.integer "idReturn"
    t.integer "idItem"
    t.integer "quantity"
  end

  create_table "tblownertypes", id: false, force: true do |t|
    t.integer "idOwner"
    t.string  "Owner",   limit: 25
  end

  create_table "tblpaymentmode", id: false, force: true do |t|
    t.integer "idMode"
    t.string  "modeName", limit: 50
  end

  create_table "tblpaymentterm", id: false, force: true do |t|
    t.integer "idTerm",              default: 0, null: false
    t.string  "termName", limit: 50
    t.integer "idMode"
  end

  create_table "tblpaymenttype", id: false, force: true do |t|
    t.integer "idType",              default: 0, null: false
    t.string  "typeName", limit: 25
    t.integer "idMode"
  end

  create_table "tblposition", id: false, force: true do |t|
    t.integer "idPosition"
    t.string  "position",   limit: 100
  end

  create_table "tblprivilege", id: false, force: true do |t|
    t.integer "id"
    t.string  "privilege", limit: 50
  end

  create_table "tblprovince", id: false, force: true do |t|
    t.string "province", limit: 30
    t.string "regions",  limit: 20
  end

  create_table "tblpullout", id: false, force: true do |t|
    t.integer "idPullOut"
    t.string  "pulloutID",   limit: 15
    t.date    "datePullOut"
    t.string  "origin",      limit: 50
    t.string  "destination", limit: 15
    t.string  "attention",   limit: 300
    t.string  "purpose",     limit: 300
    t.string  "preparedBy",  limit: 50
    t.string  "approvedBy",  limit: 50
    t.string  "receivedBy",  limit: 50
    t.string  "status",      limit: 25
    t.string  "remarks",     limit: 500
  end

  create_table "tblpulloutbikes", id: false, force: true do |t|
    t.integer "idPOB",                   default: 0, null: false
    t.integer "idItem"
    t.integer "idMtrbikes"
    t.integer "idPOI"
    t.integer "idPullOut"
    t.string  "pulloutID",  limit: 50
    t.string  "status",     limit: 25
    t.string  "remarks",    limit: 1000
  end

  create_table "tblpulloutitems", id: false, force: true do |t|
    t.integer "idPOI"
    t.integer "idItem"
    t.integer "qty"
    t.string  "unit",      limit: 15
    t.float   "unitPrice"
    t.float   "amount"
    t.string  "status",    limit: 25
    t.string  "remarks",   limit: 100
    t.integer "idPullOut"
    t.string  "pulloutID", limit: 15
  end

  create_table "tblqcharges", primary_key: "idCharges", force: true do |t|
    t.string  "details",  limit: 100
    t.float   "amount"
    t.integer "idQtrans",             null: false
    t.string  "qno",      limit: 15
  end

  create_table "tblqtrans", id: false, force: true do |t|
    t.integer "idQtrans",               default: 0, null: false
    t.string  "qno",        limit: 10
    t.string  "itemName",   limit: 150
    t.integer "qty"
    t.string  "unit",       limit: 15
    t.float   "amount"
    t.float   "ciwaog"
    t.float   "ciwoaog"
    t.string  "preparedBy", limit: 25
    t.string  "conforme",   limit: 25
    t.date    "dateTrans"
    t.string  "insurance",  limit: 50
    t.date    "insuExpiry"
    t.integer "idMtrbikes"
  end

  create_table "tblquotation", id: false, force: true do |t|
    t.string  "qno",           limit: 10
    t.date    "dateQuotation"
    t.date    "dateValid"
    t.integer "billTo"
    t.date    "dateInquiry"
    t.integer "idTrans"
    t.integer "idTransType"
    t.string  "transTerm",     limit: 15
    t.string  "status",        limit: 15
    t.string  "soID",          limit: 15
    t.string  "salesInvc",     limit: 25
    t.string  "salesOR",       limit: 25
  end

  create_table "tblregion", id: false, force: true do |t|
    t.string "region", limit: 20
  end

  create_table "tblreserveitems", primary_key: "idRsrvItem", force: true do |t|
    t.integer "idItem"
    t.integer "idMtrbikes"
    t.string  "itemName",   limit: 250
    t.string  "unit",       limit: 15
    t.integer "qty"
    t.float   "unitPrice"
    t.float   "amount"
    t.string  "status",     limit: 15
    t.text    "remarks"
    t.integer "idRsrv"
    t.string  "rsrvNo",     limit: 15
  end

  create_table "tblreserveorder", id: false, force: true do |t|
    t.integer "idRsrv",                 default: 0, null: false
    t.string  "rsrvNo",      limit: 15
    t.date    "dateRsrv"
    t.integer "idCustomer"
    t.string  "recievedBy",  limit: 50
    t.string  "payMode",     limit: 60
    t.string  "type",        limit: 50
    t.string  "term",        limit: 60
    t.string  "checkNo",     limit: 30
    t.float   "downpayment"
    t.string  "status",      limit: 30
    t.text    "remarks"
    t.integer "id"
    t.string  "soID",        limit: 25
  end

  create_table "tblrptcost", id: false, force: true do |t|
    t.integer "idItem"
    t.integer "code"
    t.date    "dateBeg"
    t.date    "dateRcvd"
    t.integer "qtyBeg"
    t.float   "costBeg"
    t.integer "qtyRcvd"
    t.float   "costRcvd"
    t.integer "invBeg"
    t.integer "invIn"
    t.integer "invOut"
    t.integer "invEnd"
  end

  create_table "tblrptcostbeg", id: false, force: true do |t|
    t.integer "idItem"
    t.integer "code"
    t.string  "itemName", limit: 200
    t.string  "partNo",   limit: 50
    t.string  "brand",    limit: 100
    t.string  "category", limit: 100
    t.date    "dateBeg"
    t.integer "qtyBeg"
    t.float   "costBeg"
  end

  create_table "tblrptcostout", id: false, force: true do |t|
    t.integer "idItem"
    t.integer "code"
    t.date    "dateOut"
    t.integer "qtyOut"
    t.float   "costOut"
    t.string  "soID",      limit: 20
    t.integer "salesInvc"
    t.integer "salesOR"
    t.integer "id"
    t.integer "idSales"
    t.integer "idPullOut"
    t.string  "pulloutID", limit: 20
  end

  create_table "tblrptcostrcv", id: false, force: true do |t|
    t.integer "idItem"
    t.integer "code"
    t.date    "dateRcvd"
    t.integer "qtyRcvd"
    t.float   "costRcvd"
    t.string  "roid",     limit: 20
    t.integer "idOrder"
    t.integer "pk"
  end

  create_table "tblrptcostsales", id: false, force: true do |t|
    t.integer "idItem"
    t.integer "code"
    t.string  "partNum",    limit: 30
    t.string  "itemName",   limit: 500
    t.string  "category",   limit: 50
    t.string  "brandName",  limit: 50
    t.string  "unit",       limit: 30
    t.integer "qtySold"
    t.date    "dateSold"
    t.float   "cost"
    t.float   "srp"
    t.integer "itemDscnt"
    t.integer "totalDscnt"
  end

  create_table "tblsales", id: false, force: true do |t|
    t.integer "idSales",                default: 0, null: false
    t.integer "idItem"
    t.string  "unit",       limit: 15
    t.integer "qty"
    t.float   "unitPrice"
    t.float   "cost"
    t.string  "discount",   limit: 6
    t.float   "amntDscnt"
    t.float   "amount"
    t.integer "id"
    t.string  "soID",       limit: 25
    t.string  "status",     limit: 30
    t.integer "idMtrbikes"
    t.string  "remarks",    limit: 500
  end

  create_table "tblsaleschrgs", id: false, force: true do |t|
    t.integer "idSales",             default: 0, null: false
    t.string  "details", limit: 100
    t.float   "amnt"
    t.integer "id"
  end

  create_table "tblsalesorder", id: false, force: true do |t|
    t.integer "id",                        default: 0, null: false
    t.string  "soID",          limit: 25
    t.integer "idCustomer"
    t.float   "totalDiscount"
    t.float   "amntDiscount"
    t.float   "total"
    t.string  "preparedBy",    limit: 50
    t.date    "dateSO"
    t.string  "remarks",       limit: 500
    t.string  "terms",         limit: 50
    t.string  "type",          limit: 50
    t.string  "payMode",       limit: 50
    t.string  "checkNo",       limit: 25
    t.string  "salesStatus",   limit: 15
    t.string  "qno",           limit: 10
    t.string  "salesInvc",     limit: 15
    t.string  "salesOR",       limit: 15
    t.string  "jeid",          limit: 15
  end

  create_table "tblsalestype", id: false, force: true do |t|
    t.integer "idType",                default: 0, null: false
    t.string  "salesType", limit: 100
  end

  create_table "tblseriespo", id: false, force: true do |t|
    t.integer "POnum",   null: false
    t.integer "idOrder"
  end

  create_table "tblservicecc", id: false, force: true do |t|
    t.integer "idSrvCC",             default: 0, null: false
    t.integer "idBrand"
    t.string  "ccType",   limit: 25
    t.float   "flatRate"
  end

  create_table "tblserviceinv", id: false, force: true do |t|
    t.integer "idSrvcInv",               null: false
    t.integer "idSrvcItem"
    t.integer "qtyBeg"
    t.integer "qtyIn"
    t.integer "qtyOut"
    t.integer "qtyEnd"
    t.date    "dateUpdated"
    t.float   "srp"
    t.float   "cost"
    t.string  "status",      limit: 50
    t.string  "remarks",     limit: 150
  end

  create_table "tblserviceitem", id: false, force: true do |t|
    t.integer "idSrvcItem",              null: false
    t.integer "idCategory"
    t.integer "idBrand"
    t.integer "code"
    t.string  "partNo",      limit: 50
    t.string  "itemName",    limit: 100
    t.string  "details",     limit: 500
    t.string  "unit",        limit: 15
    t.integer "begBal"
    t.float   "srp"
    t.float   "cost"
    t.date    "dateAdded"
    t.date    "dateUpdated"
    t.string  "remarks",     limit: 100
    t.string  "status",      limit: 50
  end

  create_table "tblserviceothers", id: false, force: true do |t|
    t.integer "idSrvcOther",             null: false
    t.string  "operations",  limit: 100
    t.integer "qty"
    t.float   "charge"
  end

  create_table "tblservices", id: false, force: true do |t|
    t.integer "idServices",             null: false
    t.string  "Services",   limit: 300, null: false
  end

  create_table "tblservicetime", id: false, force: true do |t|
    t.integer "idSrvcTime",            default: 0, null: false
    t.integer "idModel"
    t.string  "code",       limit: 20
    t.integer "minutes"
    t.integer "idSrvcType"
  end

  create_table "tblservicetype", id: false, force: true do |t|
    t.integer "idSrvcType",             default: 0, null: false
    t.integer "idBrand"
    t.string  "code",       limit: 20
    t.string  "operations", limit: 400
  end

  create_table "tblstockroom", id: false, force: true do |t|
    t.integer "idSkRm",              default: 0, null: false
    t.string  "stockRm", limit: 50
    t.string  "detail",  limit: 150
  end

  create_table "tblsupplier", id: false, force: true do |t|
    t.integer "idSupplier",               default: 0, null: false
    t.string  "supplierName", limit: 150
    t.string  "code",         limit: 10
    t.string  "detail",       limit: 200
    t.string  "address",      limit: 150
    t.string  "phoneNum",     limit: 15
    t.string  "faxNum",       limit: 15
    t.string  "website",      limit: 20
    t.string  "status",       limit: 15
    t.string  "taxStatus",    limit: 15
  end

  create_table "tblsuppliercontact", id: false, force: true do |t|
    t.integer "idContact"
    t.integer "idSupplier"
    t.string  "name",       limit: 50
    t.string  "address",    limit: 100
    t.string  "contactNo",  limit: 30
    t.string  "emailAdd",   limit: 30
  end

  create_table "tbltmpinventory", id: false, force: true do |t|
    t.integer "idItem"
    t.string  "poID",    limit: 15
    t.string  "roID",    limit: 15
    t.string  "soID",    limit: 15
    t.string  "item",    limit: 100
    t.string  "detail",  limit: 500
    t.integer "qty"
    t.float   "cost"
    t.integer "in"
    t.integer "out"
    t.integer "balance"
    t.date    "date"
  end

  create_table "tbltmpjoitems", id: false, force: true do |t|
    t.integer "idJOI",                 default: 0, null: false
    t.integer "idItem"
    t.integer "idSrvcItem"
    t.string  "unit",       limit: 10
    t.integer "qty"
    t.float   "unitPrice"
    t.integer "discount"
    t.float   "amntDscnt"
    t.float   "amount"
    t.string  "status",     limit: 20
    t.text    "remarks"
    t.integer "idJO"
    t.string  "joID",       limit: 15
  end

  create_table "tbltmpordereditems", primary_key: "pk", force: true do |t|
    t.integer "idOrder"
    t.integer "idItem"
    t.integer "quantity",                  null: false
    t.integer "idUnit"
    t.float   "cost"
    t.integer "balance"
    t.string  "status",        limit: 15
    t.integer "qtypending",                null: false
    t.integer "qtyreceived",               null: false
    t.integer "qtyreturned",               null: false
    t.string  "returnRemarks", limit: 100, null: false
    t.date    "dateReceived"
    t.float   "srp"
    t.float   "dealerPrice"
    t.string  "remarks",       limit: 30
    t.string  "roID",          limit: 15
    t.string  "taxStatus",     limit: 25
    t.integer "idSupplier"
  end

  create_table "tbltmppulloutbikes", id: false, force: true do |t|
    t.integer "idPOB",                   default: 0, null: false
    t.integer "idItem"
    t.integer "idMtrbikes"
    t.integer "idPOI"
    t.integer "idPullOut"
    t.string  "pulloutID",  limit: 50
    t.string  "status",     limit: 25
    t.string  "remarks",    limit: 1000
  end

  create_table "tbltmppulloutitems", id: false, force: true do |t|
    t.integer "idPOI"
    t.integer "idItem"
    t.integer "qty"
    t.string  "unit",      limit: 15
    t.float   "unitPrice"
    t.float   "amount"
    t.string  "status",    limit: 25
    t.string  "remarks",   limit: 100
    t.integer "idPullOut"
    t.string  "pulloutID", limit: 15
  end

  create_table "tbltmpqcharges", primary_key: "idCharges", force: true do |t|
    t.string  "details",  limit: 100
    t.float   "amount"
    t.integer "idQtrans",             null: false
    t.string  "qno",      limit: 15
  end

  create_table "tbltmpqtrans", id: false, force: true do |t|
    t.integer "idQtrans",               default: 0, null: false
    t.string  "qno",        limit: 10
    t.string  "itemName",   limit: 150
    t.integer "qty"
    t.string  "unit",       limit: 15
    t.float   "amount"
    t.float   "ciwaog"
    t.float   "ciwoaog"
    t.string  "preparedBy", limit: 25
    t.string  "conforme",   limit: 25
    t.date    "dateTrans"
    t.string  "insurance",  limit: 50
    t.date    "insuExpiry"
    t.integer "idMtrbikes"
  end

  create_table "tbltmpreserveitems", primary_key: "idRsrvItem", force: true do |t|
    t.integer "idItem"
    t.integer "idMtrbikes"
    t.string  "itemName",   limit: 250
    t.string  "unit",       limit: 15
    t.integer "qty"
    t.float   "unitPrice"
    t.float   "amount"
    t.string  "status",     limit: 20
    t.text    "remarks"
    t.integer "idRsrv"
    t.string  "rsrvNo",     limit: 15
  end

  create_table "tbltmpsales", id: false, force: true do |t|
    t.integer "idSales",                default: 0, null: false
    t.integer "idItem"
    t.string  "unit",       limit: 15
    t.integer "qty"
    t.float   "unitPrice"
    t.float   "cost"
    t.integer "discount"
    t.float   "amntDscnt"
    t.float   "amount"
    t.integer "id"
    t.string  "soID",       limit: 25
    t.string  "status",     limit: 30
    t.integer "idMtrbikes"
    t.string  "remarks",    limit: 500
  end

  create_table "tbltransaction", id: false, force: true do |t|
    t.integer "idTrans"
    t.string  "transaction", limit: 80
  end

  create_table "tbltranstype", id: false, force: true do |t|
    t.integer "idTransType"
    t.string  "transType",   limit: 50
    t.integer "idTrans"
  end

  create_table "tblunit", id: false, force: true do |t|
    t.integer "idUnit",            null: false
    t.string  "Unit",   limit: 15
  end

end
