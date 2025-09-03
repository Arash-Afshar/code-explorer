class Section < ApplicationRecord
  belongs_to :pdf

  validates :section_id, presence: true
  validates :section_title, presence: true
  validates :page_number, presence: true
  validates :x, presence: true
  validates :y, presence: true
  validates :width, presence: true
  validates :endx, presence: true
  validates :endy, presence: true

  validates :section_id, uniqueness: { scope: :pdf_id }

  scope :by_section_title, ->(title) { where("LOWER(section_title) LIKE LOWER(?)", "%#{title}%") }
end
