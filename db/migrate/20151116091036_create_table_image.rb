class CreateTableImage < ActiveRecord::Migration
  def change
    create_table :images do |t|
      t.integer :code
      t.string :branch
      t.attachment :photo
      t.timestamps
      
    end

    create_table "tblempauth" do |t|
      t.column "employee_id", :integer
  	  t.column "idEmp", :integer
  	  t.column "userName", :string
  	  t.column "passWord", :string
  	  t.column "branch", :string
      t.references "privilege", index: true

	  end 
 	  
    create_table "tblprivilege" do |t|
	    t.column "privilege", :string
      t.string "branch"
	  end

    create_table "tbllocation" do |t|
      t.column "idLocation", :integer
      t.column  "locationCode", :string
      t.column  "location", :string
    end

    create_table "tblemployee" do |t|
      t.integer "employee_id"
      t.integer "idEmp"
      t.string  "fName",      limit: 25
      t.string  "midInit",    limit: 2
      t.string  "lName",      limit: 25
      t.integer "idPosition",            null: false
      t.integer "idCmpny",               null: false
      t.string  "empStatus",  limit: 20
      t.string  "branch"
    end

    create_table "tblinventory" do |t|
      t.integer "inventory_id"
      t.integer  "code"
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
  end
end
