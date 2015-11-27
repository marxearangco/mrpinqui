class Privilege < ActiveRecord::Base
	self.table_name = 'tblprivilege'
	has_many :session, primary_key: 'id'
end
