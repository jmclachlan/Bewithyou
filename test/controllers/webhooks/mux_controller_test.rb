require "test_helper"
require "openssl"

class Webhooks::MuxControllerTest < ActionDispatch::IntegrationTest
  NotificationCounter = Struct.new(:live_calls, :replay_calls) do
    def send_live!
      self.live_calls += 1
    end

    def send_replay!
      self.replay_calls += 1
    end
  end

  setup do
    @previous_mux_secret = ENV["MUX_WEBHOOK_SECRET"]
    @previous_app_host = ENV["APP_HOST"]
    @previous_watch_token = ENV["WATCH_TOKEN"]
    @previous_postmark_token = ENV["POSTMARK_API_TOKEN"]
    @previous_from_email = ENV["FROM_EMAIL"]
    @previous_to_email = ENV["TO_EMAIL"]

    ENV["MUX_WEBHOOK_SECRET"] = "mux-secret"
    ENV["APP_HOST"] = "watch.example.com"
    ENV["WATCH_TOKEN"] = "watch-token"
    ENV["POSTMARK_API_TOKEN"] = "postmark-token"
    ENV["FROM_EMAIL"] = "from@example.com"
    ENV["TO_EMAIL"] = "to@example.com"

    @previous_notification_builder = Webhooks::MuxController.notification_service_builder
    StreamState.delete_all
  end

  teardown do
    ENV["MUX_WEBHOOK_SECRET"] = @previous_mux_secret
    ENV["APP_HOST"] = @previous_app_host
    ENV["WATCH_TOKEN"] = @previous_watch_token
    ENV["POSTMARK_API_TOKEN"] = @previous_postmark_token
    ENV["FROM_EMAIL"] = @previous_from_email
    ENV["TO_EMAIL"] = @previous_to_email
    Webhooks::MuxController.notification_service_builder = @previous_notification_builder
  end

  test "returns unauthorized for invalid signature" do
    payload = mux_event_payload(type: "video.live_stream.active", event_id: "evt_1")

    post "/webhooks/mux",
      params: payload,
      headers: { "CONTENT_TYPE" => "application/json", "Mux-Signature" => "t=1,v1=bad-signature" }

    assert_response :unauthorized
  end

  test "handles video.live_stream.active and sends live email once" do
    payload = mux_event_payload(
      type: "video.live_stream.active",
      event_id: "evt_live_1",
      data: { playback_ids: [{ "id" => "live_playback_123", "policy" => "public" }] }
    )

    first_notification_service = NotificationCounter.new(0, 0)
    Webhooks::MuxController.notification_service_builder = -> { first_notification_service }
    post_with_valid_signature(payload)

    assert_response :ok
    assert_equal 1, first_notification_service.live_calls

    state = StreamState.singleton!
    assert state.live?
    assert_equal "live_playback_123", state.live_playback_id
    assert_equal "evt_live_1", state.last_event_id
    assert_not_nil state.sent_live_email_at

    never_call_service = Object.new
    def never_call_service.send_live!
      raise "send_live! should not be called for duplicate event id"
    end

    Webhooks::MuxController.notification_service_builder = -> { never_call_service }
    post_with_valid_signature(payload)

    assert_response :ok
  end

  test "handles video.live_stream.idle and sets live to false" do
    StreamState.singleton!.update!(live: true, live_playback_id: "live_old")
    payload = mux_event_payload(type: "video.live_stream.idle", event_id: "evt_idle_1")

    post_with_valid_signature(payload)

    assert_response :ok
    state = StreamState.singleton!
    assert_not state.live?
    assert_equal "evt_idle_1", state.last_event_id
  end

  test "handles video.asset.live_stream_completed and sends replay email once" do
    payload = mux_event_payload(
      type: "video.asset.live_stream_completed",
      event_id: "evt_replay_1",
      data: { playback_ids: [{ "id" => "vod_playback_123", "policy" => "public" }] }
    )

    replay_notification_service = NotificationCounter.new(0, 0)
    Webhooks::MuxController.notification_service_builder = -> { replay_notification_service }
    post_with_valid_signature(payload)

    assert_response :ok
    assert_equal 1, replay_notification_service.replay_calls

    state = StreamState.singleton!
    assert_equal "vod_playback_123", state.vod_playback_id
    assert_equal "evt_replay_1", state.last_event_id
    assert_not_nil state.sent_replay_email_at
  end

  private

  def mux_event_payload(type:, event_id:, data: {})
    {
      id: event_id,
      type: type,
      data: data
    }.to_json
  end

  def post_with_valid_signature(payload)
    timestamp = Time.current.to_i
    digest = OpenSSL::HMAC.hexdigest("SHA256", ENV.fetch("MUX_WEBHOOK_SECRET"), "#{timestamp}.#{payload}")
    signature = "t=#{timestamp},v1=#{digest}"

    post "/webhooks/mux",
      params: payload,
      headers: { "CONTENT_TYPE" => "application/json", "Mux-Signature" => signature }
  end
end
