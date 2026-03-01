class Webhooks::MuxController < ApplicationController
  skip_forgery_protection
  class_attribute :notification_service_builder, default: -> { StreamNotificationService.new }

  def create
    raw_payload = request.raw_post
    signature = request.headers["Mux-Signature"]
    secret = ENV["MUX_WEBHOOK_SECRET"]

    return head :unauthorized unless MuxWebhookVerifier.valid?(header: signature, payload: raw_payload, secret: secret)

    event = JSON.parse(raw_payload)
    event_id = event["id"]
    event_type = event["type"]
    return head :bad_request if event_id.blank? || event_type.blank?

    stream_state = StreamState.singleton!

    stream_state.with_lock do
      stream_state.reload
      if stream_state.last_event_id == event_id
        return head :ok
      end

      handle_event(stream_state: stream_state, event: event, event_type: event_type)
      stream_state.update!(last_event_id: event_id)
    end

    head :ok
  rescue JSON::ParserError
    head :bad_request
  end

  private

  def handle_event(stream_state:, event:, event_type:)
    case event_type
    when "video.live_stream.active"
      handle_live_stream_active(stream_state, event)
    when "video.live_stream.idle"
      stream_state.update!(live: false)
    when "video.asset.live_stream_completed"
      handle_replay_ready(stream_state, event)
    end
  end

  def handle_live_stream_active(stream_state, event)
    live_playback_id = first_playback_id_from(
      event.dig("data", "playback_ids"),
      event.dig("data", "live_stream", "playback_ids")
    )

    updates = { live: true }
    updates[:live_playback_id] = live_playback_id if live_playback_id.present?
    stream_state.update!(updates)

    return if stream_state.sent_live_email_at.present?

    notification_service.send_live!
    stream_state.update!(sent_live_email_at: Time.current)
  end

  def handle_replay_ready(stream_state, event)
    vod_playback_id = first_playback_id_from(
      event.dig("data", "playback_ids"),
      event.dig("data", "asset", "playback_ids")
    )

    updates = {}
    updates[:vod_playback_id] = vod_playback_id if vod_playback_id.present?
    stream_state.update!(updates) if updates.any?

    return if stream_state.sent_replay_email_at.present?

    notification_service.send_replay!
    stream_state.update!(sent_replay_email_at: Time.current)
  end

  def first_playback_id_from(*candidates)
    candidates.compact.each do |playback_ids|
      playback_id = Array(playback_ids).filter_map { |entry| entry.is_a?(Hash) ? entry["id"] : nil }.first
      return playback_id if playback_id.present?
    end

    nil
  end

  def notification_service
    @notification_service ||= self.class.notification_service_builder.call
  end
end
