class MainController < ApplicationController
  #caches_page :index, :show  
  skip_before_filter :verify_authenticity_token, :only => [:index, :search]
  respond_to :html, :js
  def index
  	tree
  end
  
  def search1
    parm = params[:id].split('-')
    if parm[0]=='0'
      @items = Inventory.select('tblinventory.code, a.partnum, a.itemname, qtyEnd, srp, a.vin').joins('Left Join tblitem a on a.code = tblinventory.code').where('a.idCategory=?',parm[1])    
    else
      @items = Inventory.select('tblinventory.code, a.partnum, a.itemname, qtyEnd, srp, a.vin').joins('Left Join tblitem a on a.code = tblinventory.code').where('a.idCategory=? and a.idBrand=?',parm[0],parm[1])
    end
    @photogrid = ''
    @items.each do |i|
      @c = i.code
      @photo = '/assets/ring.png'
      @photogrid << '<li>'
      @photogrid << '<ul class="imgborder pricing-table">'
      @photogrid << '<li style="list-style: none; width"><a href="/main/'<< @c.to_s<<'/view" data-reveal-id="myModal" data-reveal-ajax="true" data-remote="true">'
      @image = Image.where("code = ?", i.code)
        if @image
          @image.each do |p|
            @photo = p.photo.url(:medium)
          end
        end
          #@photo = "/assets/ring.png"
          #@photogrid << '<img src="/assets/ring.png" style="height: 100px; width: 100px" />'
        #end
      @photogrid << '<img src="' << @photo << '" style="height: 100px; width: 100px" />'
      @photogrid << '</a></li>'
      @photogrid << '<li style="list-style: none; font: italic 10px gray">' << i.itemname << '</li>'
      @photogrid << '</ul>'
      @photogrid << '</li>'
    end
  end
  
  def search
    parm = params[:id].split('-')
    if parm[0]=='0'
      @items = Inventory.select('tblinventory.code, a.partnum, a.itemname, qtyEnd, srp, a.vin').joins('Left Join tblitem a on a.code = tblinventory.code').where('a.idCategory=?',parm[1])    
    else
      @items = Inventory.select('tblinventory.code, a.partnum, a.itemname, qtyEnd, srp, a.vin').joins('Left Join tblitem a on a.code = tblinventory.code').where('a.idCategory=? and a.idBrand=?',parm[0],parm[1])
    end
    @photogrid = ''
    @items.each do |i|
      @c = i.code
      @photo = '/assets/ring.png'
      @photogrid << '<li><a href="/main/'<< @c.to_s<<'/view" data-reveal-id="myModal" data-reveal-ajax="true" data-remote="true">'
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

  def view
    @item = Inventory.select('tblinventory.code, a.partnum, a.itemname, tblinventory.qtyEnd, tblinventory.srp, tblinventory.cost, a.vin, a.detail').joins('Left Join tblitem a on a.code = tblinventory.code').where('tblinventory.code=?',params[:id])
    @image = Image.where("code = ?", params[:id])
    @img=nil
    if @image
      @image.each do |i|
        @img = i.photo.url(:medium)
      end
    end
    render layout: false
  end
  
  def tree
  	cat = Category.order(:category).where("idCategory<>'8'") 
  	@treeview = ''
  	cat.each do |c|
  	 @treeview << "<ul><li class='node collapsed'>\n" << "<span class='leaf'><a href='main/0-#{c.idCategory}/search' data-remote=true>#{c.Category}</a></span>\n"  << "<span class='node-toggle'></span>\n"
  	 brand = Brand.where("idCategory=?",c.idCategory).order(:brandName)
  	 @treeview << "<ul>\n"
  	 brand.each do |b|
  	 	@treeview <<"<li><span class='leaf'><a href='main/#{c.idCategory}-#{b.idBrand}/search' data-remote=true>#{b.brandName}</a></span></li>"
  	 end
  	 @treeview << "</ul>\n" << "</li></ul>"
  	end
  end

  def image
    @id = params[:id]
    @img = Image.new
    render layout: false
  end

  def edit
    sql = 'tblinventory.code, a.partnum, a.itemname, tblinventory.qtyEnd, tblinventory.qtyBeg, tblinventory.qtyIn, tblinventory.qtyOut, tblinventory.srp, tblinventory.cost, a.vin, a.detail'
    @inv = Inventory.select(sql).joins('Left Join tblitem a on a.code = tblinventory.code').where('tblinventory.code=?',params[:id])
    render layout: false
  end

  def save
     @inv = Inventory.where("code=?",params[:id])
     @inv.each do |i|
      i.qtyBeg = params[:beg]
      i.qtyIn = params[:in]
      i.qtyOut = params[:out]
      i.qtyEnd = params[:end]
      i.save
     end
     redirect_to request.env["HTTP_REFERER"]
  end

  def addimg
   photo = Image.find_by(code: params[:id])
   
    if photo
      photo.destroy
    end
      i = params.require(:image).permit(:code,:photo)  
      @img = Image.create(i)
      @img.save
      view
    
      respond_to do |format|
        format.js
      end
    
  end
 
  
  def show
    
  end
  

end

    