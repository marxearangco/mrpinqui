class Category < ActiveRecord::Base
	self.table_name = 'tblitemcategory'
	has_many :brand, foreign_key: 'category_id'
	belongs_to :item, foreign_key: 'category_id'
	
end
