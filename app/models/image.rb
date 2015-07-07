class Image < ActiveRecord::Base
  has_attached_file :photo, :styles => { :medium => "100x100>", :thumb => "50x50>" }, :default_url => "/images/:style/missing.png"
  validates_attachment_content_type :photo, :content_type => /\Aimage\/.*\Z/
	
end