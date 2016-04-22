class Session < ActiveRecord::Base
	self.table_name = 'tblempauth'
	belongs_to :privilege, foreign_key: 'privilege_id'
end
