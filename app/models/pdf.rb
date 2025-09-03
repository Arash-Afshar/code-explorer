class Pdf < ApplicationRecord
  has_many :sections, dependent: :destroy

  validates :name, presence: true
  validates :content, presence: true

  before_save :process_uploaded_file

  private

  def process_uploaded_file
    if content.is_a?(ActionDispatch::Http::UploadedFile)
      self.content = content.read
    end
  end
end
