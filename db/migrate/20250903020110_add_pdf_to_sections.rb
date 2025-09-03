class AddPdfToSections < ActiveRecord::Migration[8.0]
  def change
    add_reference :sections, :pdf, null: false, foreign_key: true
  end
end
