module MainHelper

	def peso(amt)
		number_with_precision(amt, precision: 2, separator: '.', delimiter: ',')
	end

	def save_categoryparamsid
		@category_params = params[:id]
	end
end
