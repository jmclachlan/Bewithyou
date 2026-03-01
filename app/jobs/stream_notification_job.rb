class StreamNotificationJob < ApplicationJob
  queue_as :default
  class_attribute :notification_service_builder, default: -> { StreamNotificationService.new }

  def perform(kind)
    stream_state = StreamState.singleton!

    stream_state.with_lock do
      case kind.to_s
      when "live"
        return if stream_state.sent_live_email_at.present?

        notification_service.send_live!
        stream_state.update!(sent_live_email_at: Time.current)
      when "replay"
        return if stream_state.sent_replay_email_at.present?

        notification_service.send_replay!
        stream_state.update!(sent_replay_email_at: Time.current)
      else
        raise ArgumentError, "Unknown notification kind: #{kind}"
      end
    end
  end

  private

  def notification_service
    @notification_service ||= self.class.notification_service_builder.call
  end
end
