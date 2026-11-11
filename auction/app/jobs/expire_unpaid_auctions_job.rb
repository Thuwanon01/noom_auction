# Safety net (config/recurring.yml) for lost ExpirePaymentJobs.
class ExpireUnpaidAuctionsJob < ApplicationJob
  queue_as :default

  def perform
    Auction.payment_overdue.find_each { |auction| ExpirePayment.call(auction) }
  end
end
