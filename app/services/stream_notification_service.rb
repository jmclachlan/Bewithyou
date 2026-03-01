class StreamNotificationService
  LIVE_SUBJECT = "Game is LIVE".freeze
  REPLAY_SUBJECT = "Replay is ready".freeze

  def initialize(email_client: PostmarkClient.new, app_host: ENV["APP_HOST"], watch_token: ENV["WATCH_TOKEN"])
    @email_client = email_client
    @app_host = app_host
    @watch_token = watch_token
  end

  def send_live!
    @email_client.send_email(subject: LIVE_SUBJECT, body: "Watch now -> #{watch_url}")
  end

  def send_replay!
    @email_client.send_email(subject: REPLAY_SUBJECT, body: "Watch replay -> #{watch_url}")
  end

  private

  def watch_url
    raise PostmarkClient::DeliveryError, "APP_HOST and WATCH_TOKEN must be present" if @app_host.blank? || @watch_token.blank?

    host_without_scheme = @app_host.to_s.sub(%r{\Ahttps?://}i, "")
    "https://#{host_without_scheme}/g/#{@watch_token}"
  end
end
