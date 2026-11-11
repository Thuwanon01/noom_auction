class AuctionsController < ApplicationController
  LOAD_ERRORS = [ ActiveRecord::ActiveRecordError ].freeze

  def index
    @search = AuctionSearch.new(params)
    @auctions = @search.records
    @any_auctions = @search.total.positive? || Auction.publicly_listed.exists?
    session[:catalog_query] = request.query_parameters.except("page").merge(page: @search.page).compact_blank.to_query
  rescue *LOAD_ERRORS => e
    Rails.logger.error("[auctions#index] #{e.class}: #{e.message}")
    @search ||= AuctionSearch.new
    @auctions = []
    @load_error = true
    render :index, status: :service_unavailable
  end

  def show
    @auction = Auction.publicly_listed.includes(product: :seller).find(params[:id])
    @now = Time.current
    @action_state = AuctionActionState.for(viewer: current_user, auction: @auction, now: @now)
    @bids = helpers.bid_history_visible?(@auction, current_user, now: @now) ? @auction.bids.includes(:user).order(placed_at: :desc, id: :desc).to_a : []
  rescue ActiveRecord::RecordNotFound
    render :not_found, status: :not_found
  end
end
