# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).
#
# Examples:
#
#   cities = City.create([{ name: 'Chicago' }, { name: 'Copenhagen' }])
#   Mayor.create(name: 'Emanuel', city: cities.first)


  # connection=ActiveRecord::Base.connection
  # strsql = 'insert into "tblempauth"("id","idEmp","userName","passWord","privilege") values(1,1,\'administrator\',\'p@$$w0rd\',1)'
  # connection.execute(strsql)
  # strsql = 'insert into "tblprivilege"("id","privilege") values(1,\'Administrator\')'
  # connection.execute(strsql)
  privilege = Privilege.create([{id: '1', privilege: 'Administrator'}])
  s = Session.new
  s.id = '1'
  s.idEmp= '1'
  s.userName= 'administrator'
  s.passWord= 'p@$$w0rd'
  s.privilege= privilege.first
  s.save