require "test_helper"

class WatchControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_watch_token = ENV["WATCH_TOKEN"]
    ENV["WATCH_TOKEN"] = "top-secret-token"
    StreamState.delete_all
  end

  teardown do
    ENV["WATCH_TOKEN"] = @previous_watch_token
  end

  test "returns 404 when token is invalid" do
    get "/g/wrong-token"

    assert_response :not_found
  end

  test "renders live playback when stream is live" do
    StreamState.singleton!.update!(live: true, live_playback_id: "live123")

    get "/g/top-secret-token"

    assert_response :success
    assert_includes response.body, "LIVE"
    assert_includes response.body, 'playback-id="live123"'
    assert_includes response.body, 'stream-type="live"'
    assert_includes response.body, "turbo-cable-stream-source"
    assert_includes response.body, 'id="watch_state"'
  end

  test "renders replay when not live but replay exists" do
    StreamState.singleton!.update!(live: false, vod_playback_id: "vod456")

    get "/g/top-secret-token"

    assert_response :success
    assert_includes response.body, "Game Replay"
    assert_includes response.body, 'playback-id="vod456"'
  end

  test "renders not live yet message when no playback ids exist" do
    StreamState.singleton!.update!(live: false, live_playback_id: nil, vod_playback_id: nil)

    get "/g/top-secret-token"

    assert_response :success
    assert_includes response.body, "Not live yet."
    assert_includes response.body, "update automatically"
  end
end
