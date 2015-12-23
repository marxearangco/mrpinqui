class Privilege < ActiveRecord::Base
	self.table_name = 'tblprivilege'
	has_many :session, primary_key: 'employee_id'
end
