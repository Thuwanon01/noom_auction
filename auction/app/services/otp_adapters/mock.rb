# Development/test OTP delivery: writes the code to the Rails log instead of
# sending an SMS. Tests read the last code from OtpAdapters::Mock.deliveries.
module OtpAdapters
  class Mock
    MAX_KEPT = 50

    def self.deliveries
      @deliveries ||= []
    end

    def self.last_code_for(phone)
      deliveries.reverse.find { |d| d[:phone] == phone }&.fetch(:code)
    end

    def deliver(phone:, code:)
      raise "OtpAdapters::Mock must not be used in production" if Rails.env.production?

      self.class.deliveries << { phone: phone, code: code }
      self.class.deliveries.shift while self.class.deliveries.size > MAX_KEPT
      Rails.logger.info("[OTP mock] code for #{phone}: #{code}")
    end
  end
end
