class Pdf < ApplicationRecord
  has_many :sections, dependent: :destroy

  validates :name, presence: true
  validates :content, presence: true

  before_save :process_uploaded_file

  def extract
    require "toc_extract"

    # Create a temporary file from the binary content
    temp_file = Tempfile.new([ "pdf", ".pdf" ])
    temp_file.binmode
    temp_file.write(self.content)
    temp_file.rewind

    begin
      toc_start_page = 1 # This true only for pdfs in cb-mpc
      toc_end_page = find_toc_end_page(temp_file.path)

      # Use the new extract method to get TOC data
      sections = TocExtract.extract(temp_file.path, nil, toc_start_page, toc_end_page)

      require "pdf/reader"
      require "pdf/reader/find_text"

      PDF::Reader.open(temp_file.path) do |reader|
        reader.pages.each_with_index do |page, page_num|
          page.extend(PDF::Reader::FindText)
          runs = page.runs(merge: false)

          runs.each do |run|
            content_parts << run.text
          end
        end
      end

      content = content_parts.join

      return sections, content

    ensure
      temp_file.close
      temp_file.unlink
    end
  end

  private

  def process_uploaded_file
    if content.is_a?(ActionDispatch::Http::UploadedFile)
      self.content = content.read
    end
  end

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
            toc_end_page = page_num
            break
          end
        end
      end
    end

    Rails.logger.info "TOC end page detected: #{toc_end_page} (after #{dependencies_count} occurrences of 'Dependencies')"
    toc_end_page
  end
end
