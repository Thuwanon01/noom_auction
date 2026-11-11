class AuctionsController < ApplicationController
  include AuctionDetail

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
    load_auction_detail(params[:id])
  rescue ActiveRecord::RecordNotFound
    render :not_found, status: :not_found
  end
end
