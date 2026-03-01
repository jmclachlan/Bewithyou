require "test_helper"

class ProcessedWebhookEventTest < ActiveSupport::TestCase
  test "claim creates a new processed event once" do
    ProcessedWebhookEvent.delete_all

    first_claim = ProcessedWebhookEvent.claim!(
      provider: "mux",
      external_event_id: "evt_123",
      event_type: "video.live_stream.active"
    )

    second_claim = ProcessedWebhookEvent.claim!(
      provider: "mux",
      external_event_id: "evt_123",
      event_type: "video.live_stream.active"
    )

    assert first_claim
    assert_not second_claim
    assert_equal 1, ProcessedWebhookEvent.count
  end
end
