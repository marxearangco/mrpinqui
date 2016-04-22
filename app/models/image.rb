# module LocalConnection
#   extend ActiveSupport::Concern
#   included do
#     establish_connection "localdb"
#   end
# end

class Image < ActiveRecord::Base
  # include LocalConnection
  belongs_to :item, foreign_key: 'code'
  has_attached_file :photo, :styles => { :medium => "500x320>", :thumb => "200x200>" }, :default_url => "/images/:style/missing.png"
  validates_attachment_content_type :photo, :content_type => /\Aimage\/.*\Z/
	
end