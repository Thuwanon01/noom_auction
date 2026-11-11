class ProductImagesController < ApplicationController
  include ProductFileActions

  def create
    image = @product.product_images.new(position: next_position, file: params[:file])
    if image.save
      render_saved(image)
    else
      render_errors(image)
    end
  end

  def destroy
    @product.product_images.find(params[:id]).destroy!
    close_gaps
    back_to_step2
  end

  # PATCH body: ids[]=3&ids[]=1&ids[]=2 in the new order. Must be exactly this product's images.
  def reorder
    ids = Array(params[:ids]).map(&:to_i)
    return head :unprocessable_entity unless ids.sort == @product.product_images.pluck(:id).sort

    ProductImage.transaction do
      ids.each_with_index { |id, i| @product.product_images.find(id).update_column(:position, i + 1) }
    end
    head :no_content
  end

  private

  def next_position = (@product.product_images.maximum(:position) || 0) + 1

  def close_gaps
    @product.product_images.reload.each_with_index { |img, i| img.update_column(:position, i + 1) }
  end
end
