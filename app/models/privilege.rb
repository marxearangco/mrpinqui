class Privilege < ActiveRecord::Base
	self.table_name = 'tblprivilege'
	belongs_to :session
end
