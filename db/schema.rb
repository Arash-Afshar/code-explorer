# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_09_03_035336) do
  create_table "pdf_sections", force: :cascade do |t|
    t.string "section_number"
    t.string "title"
    t.integer "page_number"
    t.integer "pos"
    t.string "text"
    t.float "x"
    t.float "y"
    t.float "width"
    t.float "endx"
    t.float "endy"
    t.integer "page"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "pdf_id", null: false
    t.index ["pdf_id"], name: "index_pdf_sections_on_pdf_id"
  end

  create_table "pdfs", force: :cascade do |t|
    t.string "name"
    t.binary "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "processing_status", default: "pending"
    t.text "processing_error"
    t.index ["processing_status"], name: "index_pdfs_on_processing_status"
  end

  add_foreign_key "pdf_sections", "pdfs"
end
