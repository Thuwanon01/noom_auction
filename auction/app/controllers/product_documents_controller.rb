class ProductDocumentsController < ApplicationController
  include ProductFileActions

  def create
    document = @product.product_documents.new(file: params[:file])
    if document.save
      render_saved(document)
    else
      render_errors(document)
    end
  end

  def destroy
    @product.product_documents.find(params[:id]).destroy!
    back_to_step2
  end
end
