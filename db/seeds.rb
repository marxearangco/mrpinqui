  # connection=ActiveRecord::Base.connection
  # strsql = 'insert into "tblempauth"("id","idEmp","userName","passWord","privilege") values(1,1,\'administrator\',\'p@$$w0rd\',1)'
  # connection.execute(strsql)
  # strsql = 'insert into "tblprivilege"("id","privilege") values(1,\'Administrator\')'
  # connection.execute(strsql)

  priv_list = ['Administrator','Inventory','Sales','Servicing','MRP']
  
  priv_list.each do |p|
    privilege = Privilege.create(privilege: p)
  end

  s = Session.new
  s.employee_id = '1'
  s.idEmp= '1'
  s.userName= 'administrator'
  s.passWord= 'p@$$w0rd'
  s.branch = 'CDO'
  s.privilege= Privilege.first
  s.save

  loc = Area.new
  loc.idLocation = '1'
  loc.locationCode = 'CDO'
  loc.location =  'Cagayan de Oro City'
  loc.save

  loc = Area.new
  loc.idLocation = '2'
  loc.locationCode = 'DVO'
  loc.location =  'Davao City'
  loc.save  

  loc = Area.new
  loc.idLocation = '3'
  loc.locationCode = 'ZBO'
  loc.location =  'Zamboanga City'
  loc.save  

  loc = Area.new
  loc.idLocation = '4'
  loc.locationCode = 'TAC'
  loc.location =  'Tacloban City'
  loc.save  

  loc = Area.new
  loc.idLocation = '5'
  loc.locationCode = 'BXU'
  loc.location =  'Butuan City'
  loc.save  