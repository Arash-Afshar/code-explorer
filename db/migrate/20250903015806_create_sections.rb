class CreateSections < ActiveRecord::Migration[8.0]
  def change
    create_table :sections do |t|
      t.string :section_number
      t.string :title
      t.integer :page_number
      t.integer :pos
      t.string :text
      t.float :x
      t.float :y
      t.float :width
      t.float :endx
      t.float :endy
      t.integer :page

      t.timestamps
    end
  end
end
