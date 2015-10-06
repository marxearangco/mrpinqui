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
  end

  def view
    @item = Inventory.select('tblinventory.code, a.partnum, a.itemname, tblinventory.qtyEnd, tblinventory.srp, tblinventory.cost, a.vin, a.detail').joins('Left Join tblitem a on a.code = tblinventory.code').where('tblinventory.code=?',params[:id])
    @image = Image.where("code = ?", params[:id])
    @img=nil
    if @image
      @image.each do |i|
        @img = i.photo.url(:medium)
      end
    end
  end
  
  def tree
    cat = Category.order(:category).where("idCategory<>'8'") 
    @treeview = "<div><h3>CATEGORIES:</h3></div>\n"
    @treeview << "<div class='accordion' data-role='accordion'>\n"
    cat.each do |c|
      @treeview << "<div class='frame'>"
      @treeview << "<div class='heading'>#{c.Category}</div>\n"
      brand = Brand.where("idCategory=?",c.idCategory).order(:brandName)
      @treeview << "<div class='content'>\n<ul class='accordmenu list-unstyled'>\n"
      @treeview <<"<li><a href='main/0-#{c.idCategory}/search' data-remote='true'>All</a></li>"
      brand.each do |b|
        @treeview <<"<li><a href='main/#{c.idCategory}-#{b.idBrand}/search' data-remote='true'> #{b.brandName}</a></li>"
      end
      @treeview << "</ul>\n" << "</div></div>"
    end
    @treeview << "</div>"
    respond_to do |format|
      format.html
      format.json
    end
  end

  def image
    @id = params[:id]
    @img = Image.new
  end

  def edit
    sql = 'tblinventory.code, a.partnum, a.itemname, tblinventory.qtyEnd, tblinventory.qtyBeg, tblinventory.qtyIn, tblinventory.qtyOut, tblinventory.srp, tblinventory.cost, a.vin, a.detail'
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
    j.itemName = params[:itemname]
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

private

def find_item(parm0, parm1)
  if parm0=='0'
    @items = Inventory.select('tblinventory.code, a.partnum, a.itemname, qtyEnd, srp, a.vin').joins('Left Join tblitem a on a.code = tblinventory.code').where('a.idCategory=?',parm1)
    search = Category.where('idCategory=?',parm1)
    search.each do |s|
      @search = s.Category
    end
  else
    @items = Inventory.select('tblinventory.code, a.partnum, a.itemname, qtyEnd, srp, a.vin').joins('Left Join tblitem a on a.code = tblinventory.code').where('a.idCategory=? and a.idBrand=?',parm0,parm1)
    search = Brand.where('idbrand=?',parm1)
    search.each do |s|
      @search = s.brandName
    end
  end
  @photogrid = ''
  @items.each do |i|
    @c = i.code
    @photo = '/assets/ring.png'
    @photogrid << '<li><a href="/main/'<< @c<<'/view" data-toggle="modal" data-target="#viewitem" data-remote="true">'
    @image = Image.where("code = ?", i.code)
    if @image
      @image.each do |p|
        @photo = p.photo.url(:medium)
      end
    end
    @photogrid << '<img src="' << @photo << '" style="vertical-align: middle;" />'
    @photogrid << '</a><p style="font-size: 85%; text-align: center">' << i.itemname << '</p></li>'
  end
end 


end


