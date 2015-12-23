class Item < ActiveRecord::Base
	self.table_name = 'tblitem'
	belongs_to :inventory, primary_key: 'code', foreign_key: 'code'
	has_one :image, foreign_key: 'code'
	has_one :category, primary_key: 'category_id', foreign_key: 'category_id'
	has_one :brand, primary_key: 'brand_id', foreign_key: 'brand_id'

end
