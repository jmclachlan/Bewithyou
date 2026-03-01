require "test_helper"
require "openssl"

class MuxWebhookVerifierTest < ActiveSupport::TestCase
  test "returns true for valid mux signature" do
    payload = { id: "evt_1", type: "video.live_stream.active" }.to_json
    timestamp = Time.current.to_i
    secret = "secret"
    digest = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{payload}")
    header = "t=#{timestamp},v1=#{digest}"

    assert MuxWebhookVerifier.valid?(header: header, payload: payload, secret: secret)
  end

  test "returns false for stale timestamp" do
    payload = { id: "evt_1", type: "video.live_stream.active" }.to_json
    timestamp = 10.minutes.ago.to_i
    secret = "secret"
    digest = OpenSSL::HMAC.hexdigest("SHA256", secret, "#{timestamp}.#{payload}")
    header = "t=#{timestamp},v1=#{digest}"

    assert_not MuxWebhookVerifier.valid?(header: header, payload: payload, secret: secret)
  end

  test "returns false for malformed header" do
    payload = { id: "evt_1" }.to_json

    assert_not MuxWebhookVerifier.valid?(header: "not-a-header", payload: payload, secret: "secret")
  end
end
