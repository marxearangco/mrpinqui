class CreateTableImage < ActiveRecord::Migration
  def change
    create_table :images do |t|
      t.integer :code
      t.attachment :photo
      t.timestamps
    end

    create_table "tblempauth", force: true do |t|
	  t.column "idEmp", :integer
	  t.column  "userName", :string
	  t.column  "passWord", :string
	  t.column "privilege", :integer
	end

	create_table "tblprivilege", force: true do |t|
	  t.column "privilege", :string
	end
  end
end
