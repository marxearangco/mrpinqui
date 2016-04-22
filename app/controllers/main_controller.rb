class MainController < ApplicationController
  before_action :confirm_logged_in
  #skip_before_filter :verify_authenticity_token, :only => [:index, :search, :login, :newsession]
  
  def confirm_logged_in
    unless session[:username]
      redirect_to authenticate_index_path
    else
      true
    end
  end

  def index
    tree
  end

  def search
    @listitems = nil
    add_breadcrumb "Home", root_path
    parm = params[:id].split('-')
    if params[:id]=='0-0'
      if session[:role]=='Administrator'
        @listitems = initialize_grid(
          Inventory.select('"tblinventory".branch, "tblinventory".code, "tblinventory"."qtyEnd", "tblitem".itemname, "tblitem".vin, "tblitem".category_id, "tblitem".detail')
          .joins('Inner Join tblitem on tblitem.code = tblinventory.code and tblitem.branch = tblinventory.branch')
          .where('"tblitem".itemname Ilike ?',"%#{params[:searchtext]}%").order(:code),
          per_page: '10'
          )
      else
        @listitems = initialize_grid(
          Inventory.select('"tblinventory".branch, "tblinventory".code, "tblinventory"."qtyEnd", "tblitem".itemname, "tblitem".vin, "tblitem".category_id, "tblitem".detail')
          .joins('Inner Join tblitem on tblitem.code = tblinventory.code and tblitem.branch = tblinventory.branch')
          .where('"tblitem".itemname Ilike ? and "tblinventory".branch = ?',"%#{params[:searchtext]}%",session[:branch]).order(:code),
          per_page: '10'
          )
      end
      add_breadcrumb params[:searchtext].titleize, search_main_path('0-0')
    else
       if parm[0] == '0'
        if session[:role]=='Administrator'
          @cat = Category.find_by(:category_id=>parm[1])
        else
          @cat = Category.find_by(:category_id=>parm[1], :branch=> session[:branch])
        end
        add_breadcrumb @cat.category, search_main_path(params[:id])
      else
        if session[:role]=='Administrator'
          @brand = Brand.find_by(:brand_id=>parm[1])
        else
          @brand = Brand.find_by(:brand_id=>parm[1], :branch=> session[:branch])
        end
        add_breadcrumb @brand.category.category, search_main_path(params[:id])
        add_breadcrumb @brand.brandname, search_main_path(params[:id])
      end
      find_item(parm[0],parm[1])
    end
    tree
  end

  def view
    parm = params[:id].split('-')
    @item = Inventory.select('"tblitem".*, "tblinventory".*')
    .joins('Inner Join tblitem on tblitem.code = tblinventory.code and tblitem.branch = tblinventory.branch')
    .where(:code=>parm[0], :branch=> parm[1])
    @image = Image.where(:code=>parm[0], :branch=> parm[1])
    @img=nil
    if @image
      @image.each do |i|
        @img = i.photo.url(:medium)
      end
    end
    item = Item.find_by(:code=>parm[0], :branch=> parm[1])
    add_breadcrumb item.itemname, view_main_path(params[:id])
  end

  def image
    parm = params[:id].split('-')
    @id = parm[0]
    @parmbranch = parm[1]
    @img = Image.new
  end

  def edit
    parm = params[:id].split('-')
    @inv = Inventory.where(:code=>parm[0], :branch=>parm[1])
    @cat_params = Item.where(:code=>parm[0], :branch=>parm[1])
    @cat_params.each do |c|
      @catid = c.category_id.to_s << "-" << c.brand_id.to_s
    end
    @location = Location.where(:branch=>parm[1])
    respond_to do |format|
      format.js
      format.html
    end
  end

  def save
   @inv = Inventory.where(:code=>params[:id], :branch=>session[:branch])
   @inv.each do |i|
      i.qtyBeg = params[:beg]
      i.qtyIn = params[:in]
      i.qtyOut = params[:out]
      i.qtyEnd = params[:end]
      i.srp = params[:srp].to_f
      i.cost = params[:cost].to_f
      i.save
   end
   @item = Item.where(:code=> params[:id], :branch=>session[:branch])
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
    photo = Image.find_by(code: params[:code], branch: params[:branch])
    if photo
      photo.destroy
    end
    i = params.require(:image).permit(:code,:photo,:branch)
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
    # @maxcount = @datas.size
    tbl_array=["tblitembrand","tblitemcategory","tblemployee","tblinventory","tblitem","tblempauth","tblitemvin"]
    # @connection.execute('Truncate table images')
    @datas.each do |d|
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
        @read = @read.gsub("Category","category")
        @read = @read.gsub("idcategory","category_id")
        @read = @read.gsub("idBrand","brand_id")
        @read = @read.gsub("brandName","brandname")
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

        
        if table_name == 'tblempauth'
          @read = @read.gsub(/\(\"id\"\,/,'("employee_id",')
        elsif table_name == 'tblinventory'
          @read = @read.gsub(/\(\"id\"\,/,'("inventory_id",')
        elsif table_name == 'tblitembrand'
          @read = @read.gsub(/\ Apparels and Merchandise/,'')
          @read = @read.gsub(/\ Apparel and Merchandise/,'')
          @read = @read.gsub(/\ Parts and Accessories/,'')
          @read = @read.gsub(/\ Motorbikes/,'')
          @read = @read.gsub(/\ Oils and Lubricants/,'')
          @read = @read.gsub(/\ Consigned Goods/,'')
        end

        if @read.first(17) == 'CREATE TABLE "tbl' or @read.first(26) == 'CREATE TABLE IF NOT EXISTS'
          # script = 'DROP TABLE IF EXISTS ' + table_name + ';'
          # if table_name ='tblprivilege'
          #   @read = @read.gsub(/\"privilege\" varchar\(50\) DEFAULT NULL/,"\"privilege\" varchar(50) DEFAULT NULL, CONSTRAINT tblprivilege_pkey PRIMARY KEY (id)")
          # end
          # script <<' '<< @read << ';'
          script << ' Delete from ' + table_name + ' where branch = \'' + session[:branch] +'\';'
          @connection.execute(script)
        elsif @read.first(16) == 'INSERT INTO "tbl'
          # script << ' Delete from table ' + table_name + ' where branch = \'' + session[:branch] +'\';'
          @connection.execute(@read)
          script << ' Update ' + table_name + ' set branch = \'' + session[:branch] +'\' where branch is null;'
          @connection.execute(script)
        end
      end
    end
    # tbl_array.each do |tbl_name|
    #   if tbl_name != 'tblempauth'
    #     # @addcolumn = 'ALTER TABLE ' + tbl_name +' ADD COLUMN branch TEXT;'
    #     @insertbr = 'update ' + tbl_name +' set branch=\'' + session[:branch] + '\''
    #     # @connection.execute(@addcolumn)
    #     @connection.execute(@insertbr)
    #   end
    # end
  end

  private

  def tree
    if session[:role]=='Administrator'
      cat = Category.select("distinct category, category_id").order(:category)
    else
      cat = Category.select("distinct category, category_id").where(:branch=>session[:branch]).order(:category)
    end
    if cat
      @treeview = "<div><h3>CATEGORIES:</h3></div>\n"
      @treeview << "<div class='accordion' data-role='accordion'>\n"
      cat.each do |c|
        get_category_icon("#{c.category}")
        @treeview << "<div class='frame'>"
        @treeview << "<div class='heading'><span class='col-xs-1 col-sm-1 col-md-1 col-lg-1'>#{@cat_icon}</span>" << " &nbsp;&nbsp;&nbsp; #{c.category}</div>\n"
        if session[:role]=='Administrator'
          brand = c.brand.where(:category_id=>c.id)
        else
          brand= c.brand.where(:branch=>"#{session[:branch]}")
        end
        @treeview << "<div class='content'>\n<ul class='accordmenu list-unstyled' style='margin-left: 10px'>\n"
        @treeview <<"<li><a href='/main/0-#{c.category_id}/search'>All</a></li>"
        brand.each do |b|
          @treeview <<"<li><a href='/main/#{c.category_id}-#{b.brand_id}/search'> #{b.brandname}</a></li>"
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
  # def tree
  #   if session[:role]=='Administrator'
  #     cat = Category.select("distinct category, category_id").order(:category)
  #   else
  #     cat = Category.where(:branch=>session[:branch]).order(:category)
  #   end
  #   if cat
  #     @treeview = "<div><h3>CATEGORIES:</h3></div>\n"
  #     @treeview << "<div class='accordion' data-role='accordion'>\n"
  #     cat.each do |c|
  #       get_category_icon("#{c.category}")
  #       @treeview << "<div class='frame'>"
  #       @treeview << "<div class='heading'><span class='col-xs-1 col-sm-1 col-md-1 col-lg-1'>#{@cat_icon}</span>" << " &nbsp;&nbsp;&nbsp; #{c.category}</div>\n"
  #       if session[:role]=='Administrator'
  #         @brand = Brand.select(:brandname,:brand_id).uniq.joins(:category).where("category like '%#{c.category}%'")
  #       else
  #         @brand = Brand.select(:brandname,:brand_id).uniq.joins(:category).where("category like '%#{c.category}%' and \"tblitembrand\".branch='#{session[:branch]}'")
  #       end
  #       @treeview << "<div class='content'>\n<ul class='accordmenu list-unstyled' style='margin-left: 10px'>\n"
  #       @treeview <<"<li><a href='/main/0-#{c.category_id}/search'>All</a></li>"
  #       @brand.each do |b|
  #         @treeview <<"<li><a href='/main/#{c.category_id}-#{b.brand_id}/search'> #{b.brandname}</a></li>"
  #       end
  #       @treeview << "</ul>\n" << "</div></div>"
  #     end
  #     @treeview << "</div>"
  #     respond_to do |format|
  #       format.html
  #       format.json
  #     end
  #   end
  # end

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
      if session[:role]=='Administrator'
        @listitems = initialize_grid(Inventory.select('"tblinventory".branch, "tblinventory".code, "tblinventory"."qtyEnd", "tblitem".itemname, "tblitem".vin, "tblitem".category_id, "tblitem".detail')
          .joins('Inner Join tblitem on tblitem.code = tblinventory.code and tblitem.branch = tblinventory.branch')
          .where('"tblitem".category_id=?',parm1).order(:code),
          per_page: '10'
          )
      else
        @listitems = initialize_grid(
          Inventory.select('"tblinventory".branch, "tblinventory".code, "tblinventory"."qtyEnd", "tblitem".itemname, "tblitem".vin, "tblitem".category_id, "tblitem".detail')
          .joins('Inner Join tblitem on tblitem.code = tblinventory.code and tblitem.branch = tblinventory.branch')
          .where('"tblitem".category_id=? and "tblinventory".branch=?',parm1,session[:branch]).order(:code),
          per_page: '10'
          )
      end
    else
      if session[:role]=='Administrator'
        @listitems = initialize_grid(
          Inventory.select('"tblinventory".branch, "tblinventory".code, "tblinventory"."qtyEnd", "tblitem".itemname, "tblitem".vin, "tblitem".category_id, "tblitem".detail')
          .joins('Inner Join tblitem on tblitem.code = tblinventory.code and tblitem.branch = tblinventory.branch')
          .where('"tblitem".category_id=? and "tblitem".brand_id=?',parm0,parm1).order(:code),
          per_page: '10'
          )
      else
      @listitems = initialize_grid(
          Inventory.select('"tblinventory".branch, "tblinventory".code, "tblinventory"."qtyEnd", "tblitem".itemname, "tblitem".vin, "tblitem".category_id, "tblitem".detail')
          .joins('Inner Join tblitem on tblitem.code = tblinventory.code and tblitem.branch = tblinventory.branch')
          .where('"tblitem".category_id=? and "tblitem".brand_id=? and "tblinventory".branch=?',parm0,parm1,session[:branch]).order(:code),
          per_page: '10'
          )
      end
    end
  end 
end


