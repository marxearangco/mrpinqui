class CreateTableImage < ActiveRecord::Migration
  def change
    create_table :images do |t|
      t.integer :code
      t.attachment :photo
      t.timestamps
    end

    create_table "tblempauth" do |t|
  	  t.column "idEmp", :integer
  	  t.column "userName", :string
  	  t.column "passWord", :string
  	  t.references "privilege", index: true
	  end 
 	  
    create_table "tblprivilege" do |t|
	    t.column "privilege", :string
	  end

    create_table "tblemployee", primary_key: "idEmp" do |t|
      t.string  "fName",      limit: 25
      t.string  "midInit",    limit: 2
      t.string  "lName",      limit: 25
      t.integer "idPosition",            null: false
      t.integer "idCmpny",               null: false
      t.string  "empStatus",  limit: 20
    end

  end
end
