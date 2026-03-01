class WatchController < ApplicationController
  def show
    return head :not_found unless valid_watch_token?(params[:token])

    @stream_state = StreamState.singleton!
  end

  private

  def valid_watch_token?(provided_token)
    expected_token = ENV["WATCH_TOKEN"].to_s
    return false if expected_token.blank? || provided_token.blank?
    return false if provided_token.bytesize != expected_token.bytesize

    ActiveSupport::SecurityUtils.secure_compare(provided_token, expected_token)
  rescue ArgumentError
    false
  end
end
