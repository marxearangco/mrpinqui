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

ActiveRecord::Schema.define(version: 0) do

  create_table "tblbikemodels", primary_key: "idModel", force: true do |t|
    t.integer "idBrand"
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

  create_table "tblcourier", primary_key: "idCourier", force: true do |t|
    t.string "courier", limit: 50
    t.string "details", limit: 200
    t.string "address", limit: 400
    t.string "telNum",  limit: 15
    t.string "faxNum",  limit: 15
    t.string "website", limit: 50
  end

  create_table "tblcustomer", primary_key: "idCustomer", force: true do |t|
    t.string "fName",        limit: 50
    t.string "midInit",      limit: 2
    t.string "lName",        limit: 50
    t.string "address",      limit: 250
    t.string "phonenum",     limit: 20
    t.string "emailAddress", limit: 50
    t.string "landlinenum",  limit: 13
    t.date   "birthdate"
    t.string "city",         limit: 50
    t.string "province",     limit: 50
    t.string "region",       limit: 20
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

  create_table "tblcustomerservicing", primary_key: "idServicing", force: true do |t|
    t.string  "serviceNo",  limit: 15
    t.integer "idCustomer"
    t.integer "idItem"
    t.string  "barcode"
    t.date    "dateTrans"
    t.integer "InCharge"
    t.string  "remarks",    limit: 500
  end

  create_table "tbldeliveries", primary_key: "idDel", force: true do |t|
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

  create_table "tblemployee", primary_key: "idEmp", force: true do |t|
    t.string  "fName",      limit: 25
    t.string  "midInit",    limit: 2
    t.string  "lName",      limit: 25
    t.integer "idPosition",            null: false
    t.integer "idCmpny",               null: false
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
    t.float   "srp",     limit: 15
    t.float   "cost",    limit: 15
  end

  create_table "tblitem", primary_key: "idItem", force: true do |t|
    t.integer "idSupplier"
    t.integer "idBrand"
    t.string  "itemName",     limit: 100
    t.text    "detail"
    t.integer "idCategory"
    t.integer "idUnit"
    t.integer "code"
    t.string  "barcode",      limit: 10
    t.float   "cost",         limit: 12
    t.float   "sellingPrice", limit: 12
    t.integer "begBalance",               null: false
    t.date    "dateInput"
    t.integer "percent"
    t.float   "dealerPrice",  limit: 15
    t.date    "dateUpdated"
    t.string  "itemStatus",   limit: 20
    t.integer "idLocation"
    t.string  "partNum",      limit: 20
    t.string  "itemModel",    limit: 100
    t.string  "vin",          limit: 15
    t.integer "idSkRm"
  end

  create_table "tblitembarcode", id: false, force: true do |t|
    t.integer "idBarcode"
    t.integer "pk",                     null: false
    t.string  "itemBarcode", limit: 25, null: false
    t.integer "idOrder",                null: false
    t.integer "idItem",                 null: false
    t.integer "idSales",                null: false
  end

  create_table "tblitembrand", primary_key: "idBrand", force: true do |t|
    t.string  "brandName",  limit: 100
    t.integer "idCategory",             null: false
  end

  create_table "tblitemcategory", primary_key: "idCategory", force: true do |t|
    t.string "Category", limit: 60
  end

  create_table "tblitemlocation", primary_key: "idIL", force: true do |t|
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

  create_table "tblitemmaintenance", primary_key: "idim", force: true do |t|
    t.string  "serviceNo",      limit: 15
    t.integer "idCustomer",                null: false
    t.date    "dateReceived",              null: false
    t.string  "receivedBy",     limit: 25, null: false
    t.string  "location",       limit: 10
    t.integer "services",                  null: false
    t.text    "details",                   null: false
    t.date    "dateMaintained",            null: false
    t.string  "maintainedBy",   limit: 50, null: false
    t.float   "serviceCost",    limit: 15, null: false
    t.string  "itemStatus",     limit: 30, null: false
    t.text    "itemRemarks",               null: false
    t.string  "checkedBy",      limit: 50, null: false
    t.date    "dateReleased",              null: false
    t.string  "releasedBy",     limit: 50, null: false
    t.integer "idMtrbikes"
    t.integer "idCustBike"
  end

  create_table "tblitemstatus", id: false, force: true do |t|
    t.string "itemStatus"
  end

  create_table "tblitemtax", primary_key: "idVat", force: true do |t|
    t.string  "tax",     limit: 25
    t.integer "percent",            null: false
  end

  create_table "tblitemvin", id: false, force: true do |t|
    t.string  "vin",    limit: 15
    t.integer "idSkRm"
  end

  create_table "tbljoborder", primary_key: "idJO", force: true do |t|
    t.integer "idCustomer"
    t.string  "clNo",       limit: 15
    t.date    "dateJO"
    t.integer "idMtrbikes"
    t.integer "idCustBike"
    t.string  "batteryNo",  limit: 20
    t.string  "odometer",   limit: 20
    t.integer "idBrand"
    t.integer "idModel"
    t.string  "service",    limit: 1000
    t.integer "idSrvcType"
    t.string  "code",       limit: 20
    t.integer "idSrvcTime"
    t.integer "idSrvCC"
    t.integer "minutes"
    t.float   "flatRate",   limit: 12
    t.text    "joRmrks"
    t.string  "joRcvdBy",   limit: 30
    t.string  "joPrprdBy",  limit: 30
    t.string  "joChckdBy",  limit: 30
    t.string  "joApprvdBy", limit: 30
    t.string  "joid",       limit: 10
    t.string  "jeid",       limit: 10
    t.date    "dateJE"
    t.string  "timeIn",     limit: 10
    t.string  "timeOut",    limit: 10
    t.string  "jePrprdBy",  limit: 30
    t.string  "jeNotedBy",  limit: 30
    t.string  "jeApprvdBy", limit: 30
    t.string  "status",     limit: 15
    t.string  "jeRmrks",    limit: 1000
    t.string  "soID",       limit: 15
    t.string  "salesInvc",  limit: 15
    t.string  "salesOr",    limit: 15
  end

  create_table "tbljoitems", primary_key: "idJOI", force: true do |t|
    t.integer "idItem"
    t.integer "idSrvcItem"
    t.string  "unit",       limit: 10
    t.integer "qty"
    t.float   "unitPrice",  limit: 12
    t.integer "discount"
    t.float   "amount",     limit: 15
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
    t.integer "minutes"
    t.integer "qty"
    t.float   "charge",      limit: 12
    t.string  "bikeBrand",   limit: 50
  end

  create_table "tbllocation", primary_key: "idLocation", force: true do |t|
    t.string "locationCode", limit: 10
    t.string "Location",     limit: 100
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

  create_table "tblorder", primary_key: "idOrder", force: true do |t|
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
    t.string  "poID",             limit: 16, null: false
    t.string  "roID",             limit: 16, null: false
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
  end

  create_table "tblordereditems", primary_key: "pk", force: true do |t|
    t.integer "idOrder"
    t.integer "idItem"
    t.integer "quantity"
    t.integer "idUnit"
    t.float   "cost",          limit: 12
    t.integer "balance"
    t.string  "status",        limit: 15
    t.integer "qtypending",                null: false
    t.integer "qtyreceived",               null: false
    t.integer "qtyreturned",               null: false
    t.string  "returnRemarks", limit: 100, null: false
    t.date    "dateReceived",              null: false
    t.float   "srp",           limit: 18,  null: false
    t.float   "dealerPrice",   limit: 18,  null: false
    t.string  "remarks",       limit: 30,  null: false
    t.string  "roID",          limit: 15,  null: false
    t.string  "taxStatus",     limit: 25,  null: false
    t.string  "code",          limit: 15,  null: false
  end

  create_table "tblorderreturn", primary_key: "idReturn", force: true do |t|
    t.integer "idOrder"
    t.date    "dateReturn"
    t.integer "processedReturn"
  end

  create_table "tblorderreturnitems", force: true do |t|
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

  create_table "tblpaymentterm", primary_key: "idTerm", force: true do |t|
    t.string  "termName", limit: 50
    t.integer "idMode"
  end

  create_table "tblpaymenttype", primary_key: "idType", force: true do |t|
    t.string "typeName", limit: 25
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
    t.string  "origin",      limit: 15
    t.string  "destination", limit: 15
    t.string  "attention",   limit: 300
    t.string  "purpose",     limit: 300
    t.string  "preparedBy",  limit: 50
    t.string  "approvedBy",  limit: 50
    t.string  "receivedBy",  limit: 50
    t.string  "status",      limit: 25
    t.string  "remarks",     limit: 500
  end

  create_table "tblpulloutbikes", primary_key: "idPOB", force: true do |t|
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
    t.float   "unitPrice", limit: 15
    t.float   "amount",    limit: 15
    t.string  "status",    limit: 25
    t.string  "remarks",   limit: 100
    t.integer "idPullOut"
    t.string  "pulloutID", limit: 15
  end

  create_table "tblqcharges", primary_key: "idCharges", force: true do |t|
    t.string  "details",  limit: 100
    t.float   "amount",   limit: 15
    t.integer "idQtrans",             null: false
    t.string  "qno",      limit: 15
  end

  create_table "tblqtrans", primary_key: "idQtrans", force: true do |t|
    t.string  "qno",        limit: 10
    t.integer "idItem"
    t.integer "qty"
    t.string  "unit",       limit: 15
    t.float   "amount",     limit: 15
    t.float   "ciwaog",     limit: 15
    t.float   "ciwoaog",    limit: 15
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
    t.float   "unitPrice",  limit: 12
    t.float   "amount",     limit: 15
    t.string  "status",     limit: 15
    t.text    "remarks"
    t.integer "idRsrv"
    t.string  "rsrvNo",     limit: 15
  end

  create_table "tblreserveorder", primary_key: "idRsrv", force: true do |t|
    t.string  "rsrvNo",      limit: 15
    t.date    "dateRsrv"
    t.integer "idCustomer"
    t.string  "recievedBy",  limit: 50
    t.string  "payMode",     limit: 60
    t.string  "term",        limit: 60
    t.string  "checkNo",     limit: 30
    t.float   "downpayment", limit: 15
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
    t.float   "costBeg",  limit: 18
    t.integer "qtyRcvd"
    t.float   "costRcvd", limit: 18
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
    t.float   "costBeg",  limit: 18
  end

  create_table "tblrptcostout", id: false, force: true do |t|
    t.integer "idItem"
    t.integer "code"
    t.date    "dateOut"
    t.integer "qtyOut"
    t.float   "costOut",   limit: 18
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
    t.float   "costRcvd", limit: 18
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
    t.float   "cost",       limit: 18
    t.float   "srp",        limit: 18
    t.integer "itemDscnt"
    t.integer "totalDscnt"
  end

  create_table "tblsales", primary_key: "idSales", force: true do |t|
    t.integer "idItem"
    t.string  "unit",       limit: 15
    t.integer "qty"
    t.float   "unitPrice",  limit: 15
    t.float   "cost",       limit: 15
    t.integer "discount"
    t.float   "amount",     limit: 18
    t.integer "id"
    t.string  "soID",       limit: 25
    t.string  "status",     limit: 30
    t.integer "idMtrbikes"
  end

  create_table "tblsaleschrgs", id: false, force: true do |t|
    t.integer "idSales",             default: 0, null: false
    t.string  "details", limit: 100
    t.float   "amnt",    limit: 15
    t.integer "id"
  end

  create_table "tblsalesorder", force: true do |t|
    t.string  "soID",          limit: 25
    t.integer "idCustomer"
    t.integer "totalDiscount"
    t.float   "total",         limit: 21
    t.string  "preparedBy",    limit: 50
    t.date    "dateSO"
    t.string  "remarks",       limit: 500
    t.string  "terms",         limit: 50
    t.string  "type",          limit: 25
    t.string  "payMode",       limit: 30
    t.string  "checkNo",       limit: 25
    t.string  "salesStatus",   limit: 15
    t.string  "qno",           limit: 10
    t.string  "salesInvc",     limit: 15
    t.string  "salesOR",       limit: 15
    t.string  "jeid",          limit: 15
  end

  create_table "tblsalestype", primary_key: "idType", force: true do |t|
    t.string "salesType", limit: 100
  end

  create_table "tblseriespo", primary_key: "POnum", force: true do |t|
    t.integer "idOrder"
  end

  create_table "tblservicecc", primary_key: "idSrvCC", force: true do |t|
    t.integer "idBrand"
    t.string  "ccType",   limit: 25
    t.float   "flatRate", limit: 12
  end

  create_table "tblserviceinv", primary_key: "idSrvcInv", force: true do |t|
    t.integer "idSrvcItem"
    t.integer "qtyBeg"
    t.integer "qtyIn"
    t.integer "qtyOut"
    t.integer "qtyEnd"
    t.date    "dateUpdated"
    t.float   "srp",         limit: 15
    t.float   "cost",        limit: 15
    t.string  "status",      limit: 50
    t.string  "remarks",     limit: 150
  end

  create_table "tblserviceitem", primary_key: "idSrvcItem", force: true do |t|
    t.integer "idCategory"
    t.integer "idBrand"
    t.integer "code"
    t.string  "partNo",      limit: 50
    t.string  "itemName",    limit: 100
    t.string  "details",     limit: 500
    t.string  "unit",        limit: 15
    t.integer "begBal"
    t.float   "srp",         limit: 12
    t.float   "cost",        limit: 12
    t.date    "dateAdded"
    t.date    "dateUpdated"
    t.string  "remarks",     limit: 100
    t.string  "status",      limit: 50
  end

  create_table "tblserviceothers", primary_key: "idSrvcOther", force: true do |t|
    t.string  "operations", limit: 100
    t.integer "qty"
    t.float   "charge",     limit: 12
  end

  create_table "tblservices", id: false, force: true do |t|
    t.integer "idServices",             null: false
    t.string  "Services",   limit: 300, null: false
  end

  create_table "tblservicetime", primary_key: "idSrvcTime", force: true do |t|
    t.integer "idModel"
    t.string  "code",       limit: 20
    t.integer "minutes"
    t.integer "idSrvcType"
  end

  create_table "tblservicetype", primary_key: "idSrvcType", force: true do |t|
    t.integer "idBrand"
    t.string  "code",       limit: 20
    t.string  "operations", limit: 400
  end

  create_table "tblstockroom", primary_key: "idSkRm", force: true do |t|
    t.string "stockRm", limit: 50
    t.string "detail",  limit: 150
  end

  create_table "tblsupplier", primary_key: "idSupplier", force: true do |t|
    t.string "supplierName", limit: 150
    t.string "code",         limit: 10
    t.string "detail",       limit: 200
    t.string "address",      limit: 150
    t.string "phoneNum",     limit: 15
    t.string "faxNum",       limit: 15
    t.string "website",      limit: 20
    t.string "status",       limit: 15
    t.string "taxStatus",    limit: 15
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
    t.float   "cost",    limit: 15
    t.integer "in"
    t.integer "out"
    t.integer "balance"
    t.date    "date"
  end

  create_table "tbltmpjoitems", primary_key: "idJOI", force: true do |t|
    t.integer "idItem"
    t.string  "unit",      limit: 10
    t.integer "qty"
    t.float   "unitPrice", limit: 12
    t.integer "discount"
    t.float   "amount",    limit: 15
    t.string  "status",    limit: 20
    t.text    "remarks"
    t.integer "idJO"
    t.string  "joID",      limit: 15
  end

  create_table "tbltmpordereditems", primary_key: "pk", force: true do |t|
    t.integer "idOrder"
    t.integer "idItem"
    t.integer "quantity"
    t.integer "idUnit"
    t.float   "cost",          limit: 12
    t.integer "balance"
    t.string  "status",        limit: 15
    t.integer "qtypending",                null: false
    t.integer "qtyreceived",               null: false
    t.integer "Column 4",                  null: false
    t.integer "qtyreturned",               null: false
    t.string  "returnRemarks", limit: 100, null: false
    t.date    "dateReceived",              null: false
    t.float   "srp",           limit: 18,  null: false
    t.float   "dealerPrice",   limit: 18,  null: false
    t.string  "remarks",       limit: 30,  null: false
    t.string  "roID",          limit: 15,  null: false
    t.string  "taxStatus",     limit: 25,  null: false
    t.string  "code",          limit: 50
  end

  create_table "tbltmpqcharges", primary_key: "idCharges", force: true do |t|
    t.string  "details",  limit: 100
    t.float   "amount",   limit: 15
    t.integer "idQtrans",             null: false
    t.string  "qno",      limit: 15
  end

  create_table "tbltmpqtrans", primary_key: "idQtrans", force: true do |t|
    t.string  "qno",        limit: 10
    t.integer "idItem"
    t.integer "qty"
    t.string  "unit",       limit: 15
    t.float   "amount",     limit: 15
    t.float   "ciwaog",     limit: 15
    t.float   "ciwoaog",    limit: 15
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
    t.float   "unitPrice",  limit: 12
    t.float   "amount",     limit: 15
    t.string  "status",     limit: 20
    t.text    "remarks"
    t.integer "idRsrv"
    t.string  "rsrvNo",     limit: 15
  end

  create_table "tbltmpsales", primary_key: "idSales", force: true do |t|
    t.integer "idItem"
    t.string  "unit",       limit: 15
    t.integer "qty"
    t.float   "unitPrice",  limit: 15
    t.float   "cost",       limit: 15
    t.integer "discount"
    t.float   "amount",     limit: 18
    t.integer "id"
    t.string  "soID",       limit: 25
    t.string  "status",     limit: 30
    t.integer "idMtrbikes"
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

  create_table "tblunit", primary_key: "idUnit", force: true do |t|
    t.string "Unit", limit: 15
  end

end
