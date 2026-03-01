require "test_helper"

class StreamNotificationServiceTest < ActiveSupport::TestCase
  FakeEmailClient = Struct.new(:messages) do
    def send_email(subject:, body:)
      messages << { subject: subject, body: body }
    end
  end

  test "send_live builds expected short message" do
    client = FakeEmailClient.new([])
    service = StreamNotificationService.new(
      email_client: client,
      app_host: "watch.example.com",
      watch_token: "token123"
    )

    service.send_live!

    assert_equal 1, client.messages.length
    assert_equal "Game is LIVE", client.messages.first[:subject]
    assert_equal "Watch now -> https://watch.example.com/g/token123", client.messages.first[:body]
  end

  test "send_replay normalizes host that already has scheme" do
    client = FakeEmailClient.new([])
    service = StreamNotificationService.new(
      email_client: client,
      app_host: "https://watch.example.com",
      watch_token: "token123"
    )

    service.send_replay!

    assert_equal 1, client.messages.length
    assert_equal "Replay is ready", client.messages.first[:subject]
    assert_equal "Watch replay -> https://watch.example.com/g/token123", client.messages.first[:body]
  end

  test "raises if host or token is missing" do
    client = FakeEmailClient.new([])
    service = StreamNotificationService.new(email_client: client, app_host: nil, watch_token: nil)

    assert_raises(PostmarkClient::DeliveryError) { service.send_live! }
  end
end
