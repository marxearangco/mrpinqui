# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

  create_table "tblempauth", id: false, force: true do |t|
    t.integer "id",                   null: false
    t.integer "idEmp"
    t.string  "userName",  limit: 15
    t.string  "passWord",  limit: 50
    t.integer "privilege"
  end

  create_table "tblprivilege", id: false, force: true do |t|
    t.integer "id",                   null: false
    t.string "privilege"
  end

  connection=ActiveRecord::Base.connection
  connection.execute('insert into "tblempauth"("idEmp","userName","passWord","priviledge" values(1,"administrator","p@$$w0rd",1)')
  connection.execute('insert into "tblprivilege"("id","priviledge") values(1,"administrator")')  	