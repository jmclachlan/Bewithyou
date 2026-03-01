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
end
