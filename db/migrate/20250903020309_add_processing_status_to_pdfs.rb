class AddProcessingStatusToPdfs < ActiveRecord::Migration[8.0]
  def change
    add_column :pdfs, :processing_status, :string, default: 'pending'
    add_column :pdfs, :processing_error, :text
    add_index :pdfs, :processing_status
  end
end
