class Inventory < ActiveRecord::Base
	self.table_name = 'tblinventory'
	has_one :item, foreign_key: 'code', primary_key: 'code'
	has_one :image, foreign_key: 'code', primary_key: 'code'
	
	
  	
end
