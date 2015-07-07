class Brand < ActiveRecord::Base
	self.table_name = 'tblitembrand'
	belongs_to :category
end
