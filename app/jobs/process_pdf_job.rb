class ProcessPdfJob < ApplicationJob
  queue_as :default

  def perform(pdf_id)
    pdf = Pdf.find(pdf_id)

    Rails.logger.info "Starting background PDF processing for #{pdf.name}"
    start_time = Time.current

    begin
      pdf.update(processing_status: "processing")

      sections, content = pdf.extract


      Rails.logger.info "PDF extraction completed in #{Time.current - start_time}s"

      pdf.update(
        content: content,
        processing_status: "completed"
      )

      Rails.logger.info "Starting insertion of #{sections.count} section bounding boxes"
      insertion_start = Time.current

      sections.each do |section|
        bounding_box = section.bounding_box
        if bounding_box.nil?
          bounding_box = { "x" => 1, "y" => 1, "width" => 1, "endx" => 1, "endy" => 1 }
        end

        # Ensure all required coordinates are present
        # TODO: this is a stop-gap until the bug is fixed in TocExtract gem
        x = bounding_box["x"] || bounding_box[:x] || 1
        y = bounding_box["y"] || bounding_box[:y] || 1
        width = bounding_box["width"] || bounding_box[:width] || 1
        endx = bounding_box["endx"] || bounding_box[:endx] || 1
        endy = bounding_box["endy"] || bounding_box[:endy] || 1

        PdfSection.create!(
          pdf_id: pdf.id,
          section_number: section.id,
          title: section.title,
          page_number: section.page_number,
          x: x,
          y: y,
          width: width,
          endx: endx,
          endy: endy,
          page: section.page_number,
        )
      end

      Rails.logger.info "Section bounding boxes insertion completed in #{Time.current - insertion_start}s"
      Rails.logger.info "Total processing time: #{Time.current - start_time}s"

    rescue => e
      Rails.logger.error "Background PDF processing failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      pdf.update(processing_status: "failed", processing_error: e.message)
      raise e
    end
  end
end
