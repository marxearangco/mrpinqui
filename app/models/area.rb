class Area < ActiveRecord::Base
	self.table_name = 'tbllocation'
	belongs_to :item, foreign_key: 'idLocation'
end
