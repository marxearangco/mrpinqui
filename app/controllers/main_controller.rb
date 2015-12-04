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
    add_breadcrumb "Home", root_path
    parm = params[:id].split('-')
    unless params[:id]== '0-0'
      if parm[0] == '0' then
        @cat = Category.find_by(:idCategory=>parm[1])
        add_breadcrumb @cat.Category, search_main_path(params[:id])
      else
        @brand = Brand.find(parm[1])
        add_breadcrumb @brand.category.Category, search_main_path(params[:id])
        add_breadcrumb @brand.brandName, search_main_path(params[:id])
      end
      find_item(parm[0],parm[1])
    else
      @items = Inventory.select('"tblitem".*, "tblinventory".*').joins(:item).where("itemname like ?","%#{params[:searchtext]}%")
      @listitems = initialize_grid(Item.where("itemname Ilike ?","%#{params[:searchtext]}%"),
        per_page: '10',
        )
      add_breadcrumb params[:searchtext].titleize, search_main_path('0-0')
    end

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
    item = Item.find_by(:code=>params[:id])
    add_breadcrumb item.itemname, view_main_path(params[:id])
  end

  def image
    @id = params[:id]
    @img = Image.new
  end

  def edit
    # sql = 'tblinventory.code, a.partNum, a.itemname, tblinventory.qtyEnd, tblinventory.qtyBeg, tblinventory.qtyIn, tblinventory.qtyOut, tblinventory.srp, tblinventory.cost, a.vin, a.detail'
    @inv = Inventory.select('"tblitem".*, "tblinventory".*').joins(:item).where(:code=>params[:id])
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
  @datas = File.read(@path)
  @datas = @datas.split(";")
  # @readfile = Array.new
  @maxcount = @datas.size
  tbl_array=["tblitembrand","tblitemcategory","tblemployee","tblinventory","tblitem","tblempauth","tblposition","tblprivilege","tblitemvin"]
  @connection.execute('Truncate table images')
  @datas.each do |d|
    # tbl_array.each do |table_name|
      # if tbl_array.any?{|e| d.index(e) }
      table_name = d.match(/tbl\w+/).to_s
      if table_name.in? tbl_array
        script= ''
        @read = d.squish
        @read = @read.gsub(/\`/, "\"")
        @read = @read.gsub(/\\'/, "-")
        @read = @read.gsub(/AUTO_INCREMENT=\d+/,'')
        @read = @read.gsub("ENGINE=MyISAM ",'')
        @read = @read.gsub("ENGINE=InnoDB ",'')
        @read = @read.gsub("DEFAULT CHARSET=utf8", '')
        @read = @read.gsub("DEFAULT CHARSET=latin1", '')
        @read = @read.gsub("ROW_FORMAT=COMPACT",'')
        @read = @read.gsub("ROW_FORMAT=DYNAMIC",'')
        @read = @read.gsub("AUTO_INCREMENT",'')
        @read = @read.gsub("INSERT INTO tblitemhistory",'')
        @read = @read.gsub(/0000-00-00/,'1901-01-01')
        @read = @read.gsub(/ char(50)/,' varchar(50)')
        @read = @read.gsub(/NOT NULL auto_increment/,'')
        @read = @read.gsub("unsigned zerofill ","") 
        @read = @read.gsub("unsigned","")
        @read = @read.gsub(/double\(\d+,\d+\)/,"double precision") 
        @read = @read.gsub("itemName","itemname")
        @read = @read.gsub(/\"privilege\" int/,"\"privilege_id\" int")
        @read = @read.gsub(/\"passWord\"\,\ \"privilege\"/,"\"passWord\", \"privilege_id\"")
        @read = @read.gsub(/\"passWord\"\,\"privilege\"/,"\"passWord\", \"privilege_id\"")
        @read = @read.gsub("tblitembarcode",'')
        @read = @read.gsub("tblitemhistory",'')
        @read = @read.gsub("tblitemlocation",'')
        @read = @read.gsub("tblitemmaintenance",'')
        @read = @read.gsub("tblitemstatus",'')
        @read = @read.gsub("tblitemtax",'')
        @read = @read.gsub("INSERT INTO TEMP",'')
        @read = @read.gsub(/int\(\d+\)/,'integer')
        if @read.first(17) == 'CREATE TABLE "tbl' or @read.first(26) == 'CREATE TABLE IF NOT EXISTS'
          script = 'DROP TABLE IF EXISTS ' + table_name + ';'
          if table_name ='tblprivilege'
            @read = @read.gsub(/\"privilege\" varchar\(50\) DEFAULT NULL/,"\"privilege\" varchar(50) DEFAULT NULL, CONSTRAINT tblprivilege_pkey PRIMARY KEY (id)")
          end
          script <<' '<< @read << ';'
          script << ' TRUNCATE TABLE ' + table_name + ';'
          @connection.execute(script)
        else #create code from mysqladmin
          if @read.first(16) == 'INSERT INTO "tbl'
            script = @read
          end
          @connection.execute(script)

        end
        # @readfile << script
      end
    end
    # redirect_to 'logout'
  end


  private

  def tree
    cat = Category.order(:Category)
    if cat
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

  end

  def get_category_icon(category)
    @cat_icon = nil
    case category.first(3)
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

  def find_item(parm0, parm1)
    if parm0=='0'
      @items = Inventory.select('"tblitem".*, "tblinventory".*').joins(:item).where('"tblitem"."idCategory"=?', parm1)
      # search = Category.where('"idCategory"=?',parm1)
      # search.each do |s|
      #   @search = s.Category
      # end
      @listitems = initialize_grid(Item.where('"idBrand"=?',parm1).order(:code),
        per_page: '10',

        )
    else
      @items = Inventory.select('"tblitem"."itemname","tblitem".*, "tblinventory".*').joins(:item).where('"tblitem"."idCategory"=? and "tblitem"."idBrand"=?',parm0,parm1)
      # search = Brand.where('"idBrand"=?',parm1)
      # search.each do |s|
      #   @search = s.brandName
      # end
      @listitems = initialize_grid(Item.joins(:inventory).where('"idCategory"=? and "idBrand"=?',parm0,parm1).order(:code),
        per_page: '10'
        )
    end

  end 


end


