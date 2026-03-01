require "test_helper"

class StreamNotificationJobTest < ActiveJob::TestCase
  NotificationCounter = Struct.new(:live_calls, :replay_calls) do
    def send_live!
      self.live_calls += 1
    end

    def send_replay!
      self.replay_calls += 1
    end
  end

  setup do
    @previous_job_builder = StreamNotificationJob.notification_service_builder
    StreamState.delete_all
  end

  teardown do
    StreamNotificationJob.notification_service_builder = @previous_job_builder
  end

  test "live notifications are idempotent" do
    counter = NotificationCounter.new(0, 0)
    StreamNotificationJob.notification_service_builder = -> { counter }

    StreamNotificationJob.perform_now("live")
    StreamNotificationJob.perform_now("live")

    stream_state = StreamState.singleton!
    assert_equal 1, counter.live_calls
    assert_not_nil stream_state.sent_live_email_at
  end

  test "replay notifications are idempotent" do
    counter = NotificationCounter.new(0, 0)
    StreamNotificationJob.notification_service_builder = -> { counter }

    StreamNotificationJob.perform_now("replay")
    StreamNotificationJob.perform_now("replay")

    stream_state = StreamState.singleton!
    assert_equal 1, counter.replay_calls
    assert_not_nil stream_state.sent_replay_email_at
  end

  test "unknown notification kind raises" do
    assert_raises(ArgumentError) { StreamNotificationJob.perform_now("unknown") }
  end
end
