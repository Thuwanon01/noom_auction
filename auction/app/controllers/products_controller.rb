class ProductsController < ApplicationController
  before_action :require_login
  before_action :require_onboarded, except: :index
  before_action :set_product, only: %i[step update_step]
  before_action :require_editable, only: %i[step update_step]
  before_action :require_reachable_step, only: :step

  # Replaced by the real list in M2.7 (#24); kept as the placeholder until then.
  def index
    @products = current_user.products.order(:code)
  end

  def new
    @product = Product.new
    @step = 1
    render :step
  end

  def create
    @product = current_user.products.new(step1_params)
    @step = 1
    if @product.save(context: :step1)
      redirect_to step_product_path(@product, 2)
    else
      render :step, status: :unprocessable_entity
    end
  end

  def step
    @step = params[:step].to_i
    @auction = @product.auction || @product.build_auction if @step == 3
  end

  def update_step
    @step = params[:step].to_i
    case @step
    when 1
      @product.assign_attributes(step1_params)
      saved = @product.save(context: :step1)
    when 2
      saved = @product.valid?(:step2) # files are uploaded one by one; Next only checks they are complete
    when 3
      @auction = @product.auction || @product.build_auction
      @auction.assign_attributes(auction_params)
      saved = @auction.save(context: :seller_setup)
    when 4
      return finish_step4
    else
      return render_unknown_step
    end

    if saved
      redirect_to step_product_path(@product, @step + 1)
    else
      render :step, status: :unprocessable_entity
    end
  end

  private

  # Step 4: "save as draft" keeps the product as is; "submit" re-validates every step on the server
  # (a draft can be incomplete or stale) and then sends it for admin review.
  def finish_step4
    if params[:intent] == "draft"
      return redirect_to my_products_path, notice: "บันทึกแบบร่างแล้ว"
    end

    @product.accept_terms = params.dig(:product, :accept_terms)
    if @product.valid?(:submit)
      @product.submit!
      redirect_to my_products_path, notice: "ส่งแล้ว เราจะตรวจสอบภายใน 24 ชั่วโมง"
    else
      render :step, status: :unprocessable_entity
    end
  end

  def set_product
    @product = current_user.products.find(params[:id])
  end

  def require_editable
    return if @product.editable?

    redirect_to my_products_path, alert: "สินค้านี้แก้ไขไม่ได้ในสถานะ #{@product.status_label}"
  end

  def require_reachable_step
    step = params[:step].to_i
    return if @product.can_open_step?(step)

    redirect_to step_product_path(@product, @product.next_incomplete_step), alert: "กรุณากรอกขั้นตอนก่อนหน้าให้ครบ"
  end

  def render_unknown_step
    head :not_found
  end

  def auction_params
    params.expect(auction: %i[auction_type start_price reserve_price bid_increment floor_price price_drop
                              drop_interval_minutes start_at stop_at])
  end

  def step1_params
    params.expect(product: %i[name category condition description brand model year])
  end
end
