# Sends and checks one-time passwords for phone verification.
#
#   otp = OtpService.new
#   otp.send_code("0812345678")          # => Result(status: :sent)
#   otp.verify("0812345678", "123456")   # => Result(status: :ok) or :wrong, :expired, ...
#
# Delivery goes through an adapter (config.x.otp_adapter), so a real SMS
# provider can replace OtpAdapters::Mock without touching any controller.
# An adapter only needs `deliver(phone:, code:)`.
class OtpService
  CODE_LENGTH = 6
  TTL = 5.minutes
  MAX_ATTEMPTS = 3
  RESEND_COOLDOWN = 60.seconds

  Result = Data.define(:status, :attempts_left, :retry_in) do
    def initialize(status:, attempts_left: nil, retry_in: nil) = super

    def ok? = status == :ok
    def sent? = status == :sent

    def message
      case status
      when :sent      then "OTP sent"
      when :ok        then "Phone number verified"
      when :wrong     then "Wrong OTP (#{attempts_left} #{"attempt".pluralize(attempts_left)} left)"
      when :exhausted then "Too many wrong attempts. Please request a new OTP"
      when :expired   then "OTP expired. Please request a new one"
      when :cooldown  then "Please wait #{retry_in} seconds before requesting a new OTP"
      when :not_found then "Please request an OTP first"
      end
    end
  end

  def self.default_adapter
    name = Rails.configuration.x.otp_adapter.presence or
      raise "No OTP adapter configured (set config.x.otp_adapter)"
    name.to_s.constantize.new
  end

  def initialize(adapter: self.class.default_adapter, code_generator: -> { SecureRandom.random_number(10**CODE_LENGTH) })
    @adapter = adapter
    @code_generator = code_generator
  end

  def send_code(phone)
    last = OtpChallenge.latest_for(phone)
    if last && (wait = (last.created_at + RESEND_COOLDOWN - Time.current).ceil).positive?
      return Result.new(status: :cooldown, retry_in: wait)
    end

    code = format("%0#{CODE_LENGTH}d", @code_generator.call)
    OtpChallenge.for_phone(phone).where(expires_at: ...Time.current).delete_all
    OtpChallenge.create!(phone: phone, code_digest: digest(phone, code), expires_at: TTL.from_now)
    @adapter.deliver(phone: phone, code: code)
    Result.new(status: :sent)
  end

  def verify(phone, code)
    challenge = OtpChallenge.latest_for(phone)
    return Result.new(status: :not_found) if challenge.nil?

    # Lock so parallel guesses cannot get past the attempt limit.
    challenge.with_lock { check(challenge, phone, code) }
  end

  private

  def check(challenge, phone, code)
    return Result.new(status: :not_found) if challenge.verified?
    return Result.new(status: :exhausted) if challenge.attempts >= MAX_ATTEMPTS
    return Result.new(status: :expired) if challenge.expired?

    if ActiveSupport::SecurityUtils.secure_compare(digest(phone, code.to_s.strip), challenge.code_digest)
      challenge.update!(verified_at: Time.current)
      return Result.new(status: :ok)
    end

    challenge.increment!(:attempts)
    left = MAX_ATTEMPTS - challenge.attempts
    left.zero? ? Result.new(status: :exhausted) : Result.new(status: :wrong, attempts_left: left)
  end

  def digest(phone, code)
    OpenSSL::HMAC.hexdigest("SHA256", Rails.application.secret_key_base, "#{phone}:#{code}")
  end
end
