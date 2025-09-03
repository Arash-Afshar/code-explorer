class PdfsController < ApplicationController
  def index
    @pdfs = Pdf.all
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
          processing_error: @pdf.processing_error
        }
      end
    end
  end

  def new
    @pdf = Pdf.new
  end

  def create
    @pdf = Pdf.new(pdf_params)

    if @pdf.save
      ProcessPdfJob.perform_later(@pdf.id)

      redirect_to @pdf, notice: "PDF was successfully uploaded and is being processed."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @pdf = Pdf.find(params[:id])
    @pdf.destroy

    redirect_to pdfs_url, notice: "PDF was successfully deleted."
  end

  private

  def pdf_params
    params.require(:pdf).permit(:name, :content)
  end
end
