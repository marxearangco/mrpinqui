# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)


  connection=ActiveRecord::Base.connection
  strsql = 'insert into "tblempauth"("id","idEmp","userName","passWord","privilege") values(34,1,\'administrator\',\'p@$$w0rd\',1)'
  connection.execute(strsql)
  strsql = 'insert into "tblprivilege"("id","privilege") values(30,\'administrator\')'
  connection.execute(strsql)