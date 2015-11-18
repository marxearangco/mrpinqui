class Brand < ActiveRecord::Base
	self.table_name = 'tblitembrand'
	belongs_to :category, foreign_key: 'idCategory'
	belongs_to :item, foreign_key: 'idBrand'
end
