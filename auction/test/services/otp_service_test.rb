require "test_helper"

class OtpServiceTest < ActiveSupport::TestCase
  PHONE = "0812345678"

  class FakeAdapter
    attr_reader :sent

    def initialize = @sent = []
    def deliver(phone:, code:) = @sent << [ phone, code ]
  end

  setup do
    @adapter = FakeAdapter.new
    @otp = OtpService.new(adapter: @adapter, code_generator: -> { 42 })
  end

  test "sends a zero-padded 6-digit code through the adapter" do
    assert @otp.send_code(PHONE).sent?
    assert_equal [ [ PHONE, "000042" ] ], @adapter.sent
  end

  test "stores a digest, not the code" do
    @otp.send_code(PHONE)
    challenge = OtpChallenge.latest_for(PHONE)
    assert_not_includes challenge.code_digest, "000042"
    assert_equal 64, challenge.code_digest.length
  end

  test "correct code verifies" do
    @otp.send_code(PHONE)
    assert @otp.verify(PHONE, "000042").ok?
  end

  test "a verified code cannot be used twice" do
    @otp.send_code(PHONE)
    @otp.verify(PHONE, "000042")
    assert_equal :not_found, @otp.verify(PHONE, "000042").status
  end

  test "wrong code counts down attempts with the spec message" do
    @otp.send_code(PHONE)
    result = @otp.verify(PHONE, "999999")
    assert_equal :wrong, result.status
    assert_equal "Wrong OTP (2 attempts left)", result.message
    assert_equal "Wrong OTP (1 attempt left)", @otp.verify(PHONE, "999999").message
  end

  test "attempts exhausted after three wrong codes, even the right code then fails" do
    @otp.send_code(PHONE)
    2.times { @otp.verify(PHONE, "999999") }
    assert_equal :exhausted, @otp.verify(PHONE, "999999").status
    assert_equal :exhausted, @otp.verify(PHONE, "000042").status
  end

  test "expired code fails after 5 minutes" do
    @otp.send_code(PHONE)
    travel 5.minutes + 1.second do
      assert_equal :expired, @otp.verify(PHONE, "000042").status
    end
  end

  test "code still works just before expiry" do
    @otp.send_code(PHONE)
    travel 4.minutes + 59.seconds do
      assert @otp.verify(PHONE, "000042").ok?
    end
  end

  test "verify without a sent code" do
    assert_equal :not_found, @otp.verify(PHONE, "000042").status
  end

  test "resend has a cooldown, then a new code replaces the old one" do
    @otp.send_code(PHONE)
    result = @otp.send_code(PHONE)
    assert_equal :cooldown, result.status
    assert_operator result.retry_in, :>, 0

    travel OtpService::RESEND_COOLDOWN + 1.second do
      new_otp = OtpService.new(adapter: @adapter, code_generator: -> { 777_777 })
      assert new_otp.send_code(PHONE).sent?
      assert_equal :wrong, new_otp.verify(PHONE, "000042").status
      assert new_otp.verify(PHONE, "777777").ok?
    end
  end

  test "a new code resets the attempt count" do
    @otp.send_code(PHONE)
    3.times { @otp.verify(PHONE, "999999") }
    travel OtpService::RESEND_COOLDOWN + 1.second do
      @otp.send_code(PHONE)
      assert @otp.verify(PHONE, "000042").ok?
    end
  end

  test "default adapter comes from config and is the mock in test" do
    assert_instance_of OtpAdapters::Mock, OtpService.default_adapter
  end

  test "mock adapter records the code for tests and dev" do
    OtpService.new(code_generator: -> { 123_456 }).send_code("0899999999")
    assert_equal "123456", OtpAdapters::Mock.last_code_for("0899999999")
  end
end
