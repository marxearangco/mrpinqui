# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)

  connection=ActiveRecord::Base.connection
  connection.execute('insert into "tblempauth"("idEmp","userName","passWord","priviledge") values(1,"administrator","p@$$w0rd",1)')
  connection.execute('insert into "tblprivilege"("id","priviledge") values(1,"administrator")')