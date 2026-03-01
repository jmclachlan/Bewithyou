require "test_helper"

class StreamStateTest < ActiveSupport::TestCase
  test "singleton creates and reuses one row" do
    StreamState.delete_all

    first = StreamState.singleton!
    second = StreamState.singleton!

    assert_equal first.id, second.id
    assert_equal 1, StreamState.count
    assert_not first.live?
  end

  test "playback mode resolves live replay and offline" do
    stream_state = StreamState.singleton!

    stream_state.update!(live: false, live_playback_id: nil, vod_playback_id: nil)
    assert_equal :offline, stream_state.playback_mode
    assert_nil stream_state.playback_id

    stream_state.update!(live: true, live_playback_id: "live_123", vod_playback_id: nil)
    assert_equal :live, stream_state.playback_mode
    assert_equal "live_123", stream_state.playback_id

    stream_state.update!(live: false, live_playback_id: "live_123", vod_playback_id: "vod_456")
    assert_equal :replay, stream_state.playback_mode
    assert_equal "vod_456", stream_state.playback_id
  end
end
