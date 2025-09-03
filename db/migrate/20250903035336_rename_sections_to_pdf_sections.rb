class RenameSectionsToPdfSections < ActiveRecord::Migration[8.0]
  def change
    rename_table :sections, :pdf_sections
  end
end
