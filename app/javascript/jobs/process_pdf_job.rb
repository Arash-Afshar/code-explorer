class ProcessPdfJob < ApplicationJob
  queue_as :default

  def perform(pdf_id)
    pdf = Pdf.find(pdf_id)

    Rails.logger.info "Starting background PDF processing for #{pdf.name}"
    start_time = Time.current

    begin
      sections, content = pdf.extract_with_toc_extract

      Rails.logger.info "PDF extraction completed in #{Time.current - start_time}s"

      pdf.update(
        name: "TODO",
        text: content,
        processing_status: "completed"
      )

      Rails.logger.info "Starting insertion of #{toc_data.count} section bounding boxes"
      insertion_start = Time.current

      sections.each do |section|
        Section.create!(
          pdf_id: pdf.id,
          section_id: section.section_id,
          section_title: section.title,
          page_number: section["page"],
          x: section.bbox_data["x"],
          y: section.bbox_data["y"],
          width: section.bbox_data["width"],
          endx: section.bbox_data["endx"],
          endy: section.bbox_data["endy"],
          page: section.page_number,
        )
      end

      Rails.logger.info "Section bounding boxes insertion completed in #{Time.current - insertion_start}s"
      Rails.logger.info "Total processing time: #{Time.current - start_time}s"

    rescue => e
      Rails.logger.error "Background PDF processing failed: #{e.message}"
      pdf.update(processing_status: "failed", processing_error: e.message)
      raise e
    end
  end
end
