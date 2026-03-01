class StreamState < ApplicationRecord
  BROADCAST_STREAM_NAME = "stream_state_watch".freeze

  after_commit :broadcast_watch_state

  def self.singleton!
    first_or_create!(live: false)
  end

  def self.broadcast_stream_name
    BROADCAST_STREAM_NAME
  end

  def playback_mode
    return :live if live? && live_playback_id.present?
    return :replay if vod_playback_id.present?

    :offline
  end

  def playback_id
    case playback_mode
    when :live
      live_playback_id
    when :replay
      vod_playback_id
    end
  end

  private

  def broadcast_watch_state
    broadcast_update_to(
      self.class.broadcast_stream_name,
      target: "watch_state",
      partial: "watch/state",
      locals: { stream_state: self }
    )
  end
end
