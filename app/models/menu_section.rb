class MenuSection < ActiveRecord::Base
  
  belongs_to :venue, :inverse_of => :menu_sections
  has_many :menu_section_items, :dependent => :destroy, :inverse_of => :menu_section

  accepts_nested_attributes_for :menu_section_items, allow_destroy: true

  validates :name, presence: true
  validates :venue, presence: true
  validates :position, numericality: { only_integer: true }, allow_nil: true

  default_scope { order('position ASC, id ASC') }
  
end
