class PdfsController < ApplicationController
  def index
    @pdfs = Pdf.order(created_at: :desc)
  end

  def show
    @pdf = Pdf.find(params[:id])

    respond_to do |format|
      format.html
      format.json do
        render json: {
          id: @pdf.id,
          name: @pdf.name,
          processing_status: @pdf.processing_status,
          processing_error: @pdf.processing_error,
          created_at: @pdf.created_at,
          updated_at: @pdf.updated_at
        }
      end
    end
  end

  def new
    @pdf = Pdf.new
  end

  def create
    uploaded_file = pdf_params[:content]

    if uploaded_file.is_a?(ActionDispatch::Http::UploadedFile)
      filename = uploaded_file.original_filename
      extracted_name = filename.gsub(/\.pdf$/i, "")
      file_content = uploaded_file.read
      @pdf = Pdf.new(
        name: extracted_name,
        content: file_content
      )
    else
      @pdf = Pdf.new(pdf_params)
    end

    if @pdf.save
      @pdf.update(processing_status: "pending")

      ProcessPdfJob.perform_later(@pdf.id)

      redirect_to pdfs_path, notice: "PDF '#{@pdf.name}' was successfully uploaded and is being processed."
    else
      Rails.logger.error "PDF validation failed: #{@pdf.errors.full_messages.join(', ')}"
      @pdfs = Pdf.order(created_at: :desc)
      render :index, status: :unprocessable_content
    end
  end

  def destroy
    @pdf = Pdf.find(params[:id])
    pdf_name = @pdf.name
    @pdf.destroy

    redirect_to pdfs_path, notice: "PDF '#{pdf_name}' was successfully deleted."
  end

  def preview
    @pdf = Pdf.find(params[:id])
    section_number = params[:section]

    respond_to do |format|
      format.json do
        begin
          preview_img = @pdf.preview(section_number)
          render json: {
            success: true,
            preview_image: preview_img
          }
        rescue => e
          Rails.logger.error "Preview generation failed: #{e.message}"
          render json: {
            success: false,
            error: e.message
          }, status: :internal_server_error
        end
      end
    end
  end

  def file
    @pdf = Pdf.find(params[:id])

    unless @pdf.content.present?
      render json: { error: "PDF content not available" }, status: :not_found
      return
    end

    response.headers["Content-Type"] = "application/pdf"
    response.headers["Content-Disposition"] = "inline; filename=\"#{@pdf.name}\""
    response.headers["Cache-Control"] = "public, max-age=3600"
    response.headers["Content-Length"] = @pdf.content.bytesize.to_s

    send_data @pdf.content, type: "application/pdf", disposition: "inline"
  end

  private

  def pdf_params
    params.require(:pdf).permit(:content)
  end
end
