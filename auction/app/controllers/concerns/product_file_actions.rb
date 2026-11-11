# Shared by the image and proof-document controllers (JSON for the upload widget, redirect for plain forms).
module ProductFileActions
  extend ActiveSupport::Concern

  included do
    before_action :require_login
    before_action :require_onboarded
    before_action :set_product
    before_action :require_editable
  end

  private

  def set_product
    @product = current_user.products.find(params[:product_id])
  end

  def require_editable
    return if @product.editable?

    respond_to do |format|
      format.json { render json: { errors: [ "This product can no longer be edited" ] }, status: :forbidden }
      format.html { redirect_to my_products_path, alert: "สินค้านี้แก้ไขไม่ได้" }
    end
  end

  def render_saved(record)
    render json: { id: record.id }, status: :created
  end

  def render_errors(record)
    render json: { errors: record.errors.full_messages }, status: :unprocessable_entity
  end

  def back_to_step2
    redirect_to step_product_path(@product, 2)
  end
end
