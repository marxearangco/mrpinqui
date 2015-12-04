module MainHelper

	def peso(amt)
		number_with_precision(amt, precision: 2, separator: '.', delimiter: ',')
	end

	def save_categoryparamsid
		@category_params = params[:id]
	end

	def get_category_icon(category_id)
		@cat_icon = nil
		cat = Category.find(category_id)

		case cat.Category.first(3)
		when 'App' then 
			@cat_icon = "<i style='color: #FA6800' class='fa fa-black-tie'></i>"
		when 'Bat' then
			@cat_icon = "<i style='color: #FA6800' class='fa fa-battery-half'></i>"
		when 'Mot' then
			@cat_icon = "<i style='color: #FA6800' class='fa fa-motorcycle'></i>"
		when 'Par' then
			@cat_icon = "<i style='color: #FA6800' class='fa fa-cogs'></i>"
		when 'Tir' then
			@cat_icon = "<i style='color: #FA6800' class='fa fa-gg-circle'></i>"
		when 'Con' then
			@cat_icon = "<i style='color: #FA6800' class='fa fa-edit'></i>"
		when 'Oil' then
			@cat_icon = "<i style='color: #FA6800' class='fa fa-tint'></i>"
		else
			@cat_icon = "<i style='color: #FA6800' class='fa fa-archive'></i>"
		end
	end
end
