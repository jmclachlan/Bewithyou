require "json"
require "openssl"

def assert!(condition, message)
  raise "Smoke test failed: #{message}" unless condition
end

required_env_vars = %w[
  APP_HOST
  WATCH_TOKEN
  MUX_WEBHOOK_SECRET
  POSTMARK_API_TOKEN
  FROM_EMAIL
  TO_EMAIL
]

missing_vars = required_env_vars.select { |key| ENV[key].blank? }
if missing_vars.any?
  raise "Smoke test failed: missing env vars #{missing_vars.join(', ')}"
end

notification_counter = Struct.new(:live_calls, :replay_calls) do
  def send_live!
    self.live_calls += 1
  end

  def send_replay!
    self.replay_calls += 1
  end
end.new(0, 0)

watch_token = ENV.fetch("WATCH_TOKEN")
mux_secret = ENV.fetch("MUX_WEBHOOK_SECRET")

previous_builder = Webhooks::MuxController.notification_service_builder
Webhooks::MuxController.notification_service_builder = -> { notification_counter }

begin
  StreamState.delete_all
  StreamState.singleton!

  session = ActionDispatch::Integration::Session.new(Rails.application)

  session.get("/g/invalid-token")
  assert!(session.response.status == 404, "invalid token should return 404")

  session.get("/g/#{watch_token}")
  assert!(session.response.status == 200, "valid token should return 200")
  assert!(session.response.body.include?("Not live yet."), "watch page should render offline state")

  live_event = {
    id: "smoke-live-event-1",
    type: "video.live_stream.active",
    data: {
      playback_ids: [{ "id" => "smoke_live_playback_id", "policy" => "public" }]
    }
  }.to_json

  live_timestamp = Time.current.to_i
  live_signature = OpenSSL::HMAC.hexdigest("SHA256", mux_secret, "#{live_timestamp}.#{live_event}")
  session.post(
    "/webhooks/mux",
    params: live_event,
    headers: {
      "CONTENT_TYPE" => "application/json",
      "Mux-Signature" => "t=#{live_timestamp},v1=#{live_signature}"
    }
  )

  assert!(session.response.status == 200, "live webhook should return 200")

  state = StreamState.singleton!
  state.reload
  assert!(state.live?, "stream should be marked live")
  assert!(state.live_playback_id == "smoke_live_playback_id", "live playback id should be persisted")
  assert!(state.sent_live_email_at.present?, "sent_live_email_at should be set")
  assert!(notification_counter.live_calls == 1, "live notification should be sent once")

  session.get("/g/#{watch_token}")
  assert!(session.response.status == 200, "watch page should render while live")
  assert!(session.response.body.include?("LIVE"), "watch page should show LIVE badge")
  assert!(session.response.body.include?('playback-id="smoke_live_playback_id"'), "watch page should include live playback id")

  idle_event = {
    id: "smoke-idle-event-1",
    type: "video.live_stream.idle",
    data: {}
  }.to_json

  idle_timestamp = Time.current.to_i
  idle_signature = OpenSSL::HMAC.hexdigest("SHA256", mux_secret, "#{idle_timestamp}.#{idle_event}")
  session.post(
    "/webhooks/mux",
    params: idle_event,
    headers: {
      "CONTENT_TYPE" => "application/json",
      "Mux-Signature" => "t=#{idle_timestamp},v1=#{idle_signature}"
    }
  )

  assert!(session.response.status == 200, "idle webhook should return 200")
  state.reload
  assert!(!state.live?, "stream should be marked not live after idle")

  replay_event = {
    id: "smoke-replay-event-1",
    type: "video.asset.live_stream_completed",
    data: {
      playback_ids: [{ "id" => "smoke_vod_playback_id", "policy" => "public" }]
    }
  }.to_json

  replay_timestamp = Time.current.to_i
  replay_signature = OpenSSL::HMAC.hexdigest("SHA256", mux_secret, "#{replay_timestamp}.#{replay_event}")
  session.post(
    "/webhooks/mux",
    params: replay_event,
    headers: {
      "CONTENT_TYPE" => "application/json",
      "Mux-Signature" => "t=#{replay_timestamp},v1=#{replay_signature}"
    }
  )

  assert!(session.response.status == 200, "replay webhook should return 200")
  state.reload
  assert!(state.vod_playback_id == "smoke_vod_playback_id", "vod playback id should be persisted")
  assert!(state.sent_replay_email_at.present?, "sent_replay_email_at should be set")
  assert!(notification_counter.replay_calls == 1, "replay notification should be sent once")

  session.get("/g/#{watch_token}")
  assert!(session.response.status == 200, "watch page should render for replay")
  assert!(session.response.body.include?("Game Replay"), "watch page should show replay state")
  assert!(session.response.body.include?('playback-id="smoke_vod_playback_id"'), "watch page should include replay playback id")

  puts "Smoke test passed in #{Rails.env} environment."
ensure
  Webhooks::MuxController.notification_service_builder = previous_builder
end
