class Pdf < ApplicationRecord
  has_many :pdf_sections, dependent: :destroy

  validates :content, presence: true
  validates :name, presence: true

  def extract
    temp_file = Tempfile.new([ "pdf", ".pdf" ])
    temp_file.binmode
    temp_file.write(self.content)
    temp_file.rewind

    begin
      toc_start_page = 1 # This true only for pdfs in cb-mpc
      toc_end_page = find_toc_end_page(temp_file.path)

      sections = TocExtract.extract(temp_file.path, nil, toc_start_page, toc_end_page)

      require "pdf/reader"
      require "pdf/reader/find_text"

      return sections, self.content

    rescue => e
      Rails.logger.error "PDF extraction failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise e
    ensure
      temp_file.close
      temp_file.unlink
    end
  end

  def preview(section_number)
    require "toc_extract"

    temp_file = Tempfile.new([ "pdf", ".pdf" ])
    temp_file.binmode
    temp_file.write(content)
    temp_file.rewind

    begin
      crop_width = 500
      crop_height = 300

      db_section = pdf_sections.find { |section| section.section_number == section_number }
      section = Section.new(db_section.section_number, db_section.title, db_section.page_number)
      section.bounding_box = { "x" => db_section.x, "y" => db_section.y, "width" => db_section.width, "endx" => db_section.endx, "endy" => db_section.endy }
      preview_image_blob = TocExtract.preview(temp_file.path, section, crop_width, crop_height)

      require "base64"
      "data:image/png;base64,#{Base64.strict_encode64(preview_image_blob)}"

    rescue => e
      Rails.logger.error "Preview generation error: #{e.message}"
      ""
    ensure
      temp_file.close
      temp_file.unlink
    end
  end

  private

  # Find the TOC end page by looking for the second appearance of "Dependencies"
  # This true only for pdfs in cb-mpc
  def find_toc_end_page(pdf_path)
    require "pdf/reader"

    dependencies_count = 0
    toc_end_page = 1  # Default fallback

    PDF::Reader.open(pdf_path) do |reader|
      reader.pages.each_with_index do |page, page_num|
        page_text = page.text

        if page_text.include?("Dependencies")
          dependencies_count += 1

          if dependencies_count == 2
            toc_end_page = page_num - 1
            break
          end
        end
      end
    end

    Rails.logger.info "TOC end page detected: #{toc_end_page} (after #{dependencies_count} occurrences of 'Dependencies')"
    toc_end_page
  end
end
