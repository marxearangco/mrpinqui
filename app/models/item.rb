class Item < ActiveRecord::Base
	self.table_name = 'tblitem'
	belongs_to :inventory, foreign_key: 'code'
	has_one :image, foreign_key: 'code'
	has_one :category, foreign_key: 'idCategory'
	has_one :brand, foreign_key: 'idBrand'
end
