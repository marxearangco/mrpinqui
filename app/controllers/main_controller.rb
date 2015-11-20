class MainController < ApplicationController
  before_action :confirm_logged_in
  #skip_before_filter :verify_authenticity_token, :only => [:index, :search, :login, :newsession]
  
  def confirm_logged_in
    unless session[:username]
      redirect_to authenticate_login_path
    else
      true
    end
  end

  def index
  	tree
  end
  
  def search
    parm = params[:id].split('-')
    find_item(parm[0],parm[1])
    session[:category]=params[:id]
    tree
  end

  def view
    @item = Inventory.select('"tblitem".*, "tblinventory".*').joins(:item).where(:code=>"#{params[:id]}")
    @image = Image.where(:code =>"#{params[:id]}")
    @img=nil
    if @image
      @image.each do |i|
        @img = i.photo.url(:medium)
      end
    end
  end
  
  def image
    @id = params[:id]
    @img = Image.new
  end

  def edit
    sql = 'tblinventory.code, a.partNum, a.itemname, tblinventory.qtyEnd, tblinventory.qtyBeg, tblinventory.qtyIn, tblinventory.qtyOut, tblinventory.srp, tblinventory.cost, a.vin, a.detail'
    @inv = Inventory.select(sql).joins('Left Join tblitem a on a.code = tblinventory.code').where('tblinventory.code=?',params[:id])
    @cat_params = Item.where(:code=>params[:id])
    @cat_params.each do |c|
      @catid = c.idCategory.to_s << "-" << c.idBrand.to_s
    end
    @location = Location.all
    respond_to do |format|
      format.js
      format.html
    end
  end

  def save
   @inv = Inventory.where("code=?", params[:id])
   @inv.each do |i|
    i.qtyBeg = params[:beg]
    i.qtyIn = params[:in]
    i.qtyOut = params[:out]
    i.qtyEnd = params[:end]
    i.srp = params[:srp].to_f
    i.cost = params[:cost].to_f
    i.save
  end
  @item = Item.where("code=?", params[:id])
  @item.each do |j|
    j.itemname = params[:itemname]
    j.detail = params[:detail]
    j.partNum = params[:partnum]
    j.vin = params[:location]
    j.sellingPrice = params[:srp].to_s.to_f
    j.cost = params[:cost].to_s.to_f
    j.begBalance = params[:beg]
    j.save
  end
  respond_to do |format|
    format.js
    format.html {render layout: false}
  end
end

def create
  photo = Image.find_by(code: params[:id])
  if photo
    photo.destroy
  end
  i = params.require(:image).permit(:code,:photo)
  @i = Image.create(i)
  @i.save
end

def show

end

def upload

end

def uploadsql
  @connection = ActiveRecord::Base.connection
  uploaded_io = params[:file]
  filename = uploaded_io.original_filename
  @path = File.join('public/data', filename)
  File.open(Rails.root.join('public', 'data', filename), 'wb') do |file|
    file.write(uploaded_io.read)
  end
  @data = File.read(@path)
  @datas = @data.split(";")
  @readfile = Array.new
  @datas.each do |d|
    @read = d.squish
    @read = @read.gsub(/`/) { '"' }
    @read = @read.gsub(/\\'/) {'-'}
    @read = @read.gsub("ENGINE=MyISAM ",'')
    @read = @read.gsub("ENGINE=InnoDB ",'')
    @read = @read.gsub("DEFAULT CHARSET=utf8", '')
    @read = @read.gsub("DEFAULT CHARSET=latin1", '')
    @read = @read.gsub("ROW_FORMAT=COMPACT",'')
    @read = @read.gsub("ROW_FORMAT=DYNAMIC",'')
    @read = @read.gsub("AUTO_INCREMENT=1687",'')
    @read = @read.gsub("AUTO_INCREMENT=2038",'')
    @read = @read.gsub("AUTO_INCREMENT=3010",'')
    @read = @read.gsub("AUTO_INCREMENT=878",'')
    @read = @read.gsub("AUTO_INCREMENT=9",'')
    @read = @read.gsub("AUTO_INCREMENT=15",'')
    @read = @read.gsub("AUTO_INCREMENT=879",'')
    @read = @read.gsub("AUTO_INCREMENT=318",'')
    @read = @read.gsub("AUTO_INCREMENT=3",'')
    @read = @read.gsub("AUTO_INCREMENT=5",'')
    @read = @read.gsub("AUTO_INCREMENT=12",'')
    @read = @read.gsub("AUTO_INCREMENT=7",'')
    @read = @read.gsub("AUTO_INCREMENT=23",'')
    @read = @read.gsub("AUTO_INCREMENT=15",'')
    @read = @read.gsub("INSERT INTO tblitemhistory",'')
    @read = @read.gsub(/0000-00-00/,'1901-01-01')
    @read = @read.gsub(/ char(50)/,' varchar(50)')
    @read = @read.gsub(/NOT NULL auto_increment/,'')
    @read = @read.gsub("unsigned zerofill ","") 
    @read = @read.gsub("unsigned","") 
    @read = @read.gsub("double(15,2)","double precision")
    @read = @read.gsub("double(18,2)","double precision")
    @read = @read.gsub("double(12,2)","double precision")
    @read = @read.gsub("double(21,2)","double precision")
    @read = @read.gsub("itemName","itemname")
    (1..25).each do |i|
      var = "int(" + i.to_s + ")"
      @read = @read.gsub(var,'integer')
    end

    if @read.first(16)=='INSERT INTO "tbl' or @read.first(31) == 'CREATE TABLE IF NOT EXISTS "tbl'
      if @read.first(6) == 'CREATE'

         array_table = @read.split('EXISTS ')
       array_get_table = array_table.values_at(1).join('')
       array_get_table = array_get_table.split(' (')
         table_name = array_get_table.values_at(0).join('')
         script = 'DROP TABLE ' + table_name + ';'
         script <<' '<< @read << ';'
         script << ' TRUNCATE TABLE ' + table_name + ';'

       else
         script = @read
       end
       @readfile = script
      # logger.info script
      @connection.execute(@readfile)
    end
  end

  # redirect_to :back
end


private

def tree
  cat = Category.order(:Category)
  @treeview = "<div><h3>CATEGORIES:</h3></div>\n"
  @treeview << "<div class='accordion' data-role='accordion'>\n"
  cat.each do |c|
    get_category_icon("#{c.Category}")
    @treeview << "<div class='frame'>"
    @treeview << "<div class='heading'><span class='col-xs-1 col-sm-1 col-md-1 col-lg-1'>#{@cat_icon}</span>" << " &nbsp;&nbsp;&nbsp; #{c.Category}</div>\n"
    @brand = Brand.where('"idCategory"=?', c.idCategory)
    @treeview << "<div class='content'>\n<ul class='accordmenu list-unstyled' style='margin-left: 10px'>\n"
    @treeview <<"<li><a href='/main/0-#{c.idCategory}/search'>All</a></li>"
    @brand.each do |b|
      @treeview <<"<li><a href='/main/#{c.idCategory}-#{b.idBrand}/search'> #{b.brandName}</a></li>"
    end
    @treeview << "</ul>\n" << "</div></div>"
  end
  @treeview << "</div>"
  respond_to do |format|
    format.html
    format.json
  end
end

def get_category_icon(category)
  @cat_icon = nil
  case category.first(3)
  when 'App' then 
    @cat_icon = "<i class='fa fa-black-tie'></i>"
  when 'Bat' then
    @cat_icon = "<i class='fa fa-battery-half'></i>"
  when 'Mot' then
    @cat_icon = "<i class='fa fa-motorcycle'></i>"
  when 'Par' then
    @cat_icon = "<i class='fa fa-cogs'></i>"
  when 'Tir' then
    @cat_icon = "<i class='fa fa-gg-circle'></i>"
  when 'Con' then
    @cat_icon = "<i class='fa fa-edit'></i>"
  when 'Oil' then
    @cat_icon = "<i class='fa fa-tint'></i>"
  else
    @cat_icon = "<i class='fa fa-archive'></i>"
  end
    
end

def find_item(parm0, parm1)
  if parm0=='0'
    @items = Inventory.select('"tblitem".*, "tblinventory".*').joins(:item).where('"tblitem"."idCategory"=?', parm1)
    search = Category.where('"idCategory"=?',parm1)
    search.each do |s|
      @search = s.Category
    end
    @listitems = initialize_grid(Item.where('"idBrand"=?',parm1),
      per_page: '10'
      )
  else
    @items = Inventory.select('"tblitem"."itemname","tblitem".*, "tblinventory".*').joins(:item).where('"tblitem"."idCategory"=? and "tblitem"."idBrand"=?',parm0,parm1)
    search = Brand.where('"idBrand"=?',parm1)
    search.each do |s|
      @search = s.brandName
    end
    @listitems = initialize_grid(Item.where('"idCategory"=? and "idBrand"=?',parm0,parm1),
      per_page: '10'
      )
  end

end 


end


