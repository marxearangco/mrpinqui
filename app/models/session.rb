class Session < ActiveRecord::Base
	self.table_name = 'tblempauth'
	has_one :privilege, foreign_key: 'id',  primary_key: 'privilege'
end
