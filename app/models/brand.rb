class Brand < ActiveRecord::Base
	self.table_name = 'tblitembrand'
	belongs_to :category, foreign_key: 'category_id'
	belongs_to :item, foreign_key: 'brand_id'
end
