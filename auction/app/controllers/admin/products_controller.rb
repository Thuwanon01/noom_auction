module Admin
  class ProductsController < BaseController
    before_action :set_product, only: %i[show approve reject]
    before_action :require_pending, only: %i[approve reject]

    # The review queue: oldest submission first.
    def index
      @products = Product.pending_review.includes(:seller, :auction).order(:updated_at)
    end

    def show; end

    def approve
      @product.approve!
      redirect_to admin_products_path, notice: "อนุมัติ #{@product.code} แล้ว"
    end

    def reject
      reason = params[:rejection_reason].to_s.strip
      if reason.blank?
        @product.errors.add(:base, "กรุณาระบุเหตุผลที่ไม่ผ่าน")
        return render :show, status: :unprocessable_entity
      end

      @product.reject!(reason)
      redirect_to admin_products_path, notice: "ปฏิเสธ #{@product.code} แล้ว"
    end

    private

    def set_product
      @product = Product.find(params[:id])
    end

    # Two admins can open the same product; the second decision must not overwrite the first.
    def require_pending
      return if @product.pending_review?

      redirect_to admin_products_path, alert: "#{@product.code} ไม่ได้อยู่ในสถานะรอตรวจสอบแล้ว (#{@product.status_label})"
    end
  end
end
