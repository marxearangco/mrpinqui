class Category < ActiveRecord::Base
	self.table_name = 'tblitemcategory'
	has_many :brand, foreign_key: 'idCategory'
	belongs_to :item, foreign_key: 'idCategory'
	
end
