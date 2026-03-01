require "json"
require "net/http"
require "uri"

class PostmarkClient
  API_URL = URI("https://api.postmarkapp.com/email")

  class DeliveryError < StandardError; end

  def initialize(api_token: ENV["POSTMARK_API_TOKEN"], from_email: ENV["FROM_EMAIL"], to_email: ENV["TO_EMAIL"])
    @api_token = api_token
    @from_email = from_email
    @to_email = to_email
  end

  def send_email(subject:, body:)
    validate_configuration!

    request = Net::HTTP::Post.new(API_URL)
    request["Accept"] = "application/json"
    request["Content-Type"] = "application/json"
    request["X-Postmark-Server-Token"] = @api_token
    request.body = {
      From: @from_email,
      To: @to_email,
      Subject: subject,
      TextBody: body
    }.to_json

    response = Net::HTTP.start(API_URL.host, API_URL.port, use_ssl: true) do |http|
      http.request(request)
    end

    return response if response.is_a?(Net::HTTPSuccess)

    raise DeliveryError, "Postmark request failed with status #{response.code}: #{response.body}"
  end

  private

  def validate_configuration!
    return if @api_token.present? && @from_email.present? && @to_email.present?

    raise DeliveryError, "POSTMARK_API_TOKEN, FROM_EMAIL, and TO_EMAIL must be present"
  end
end
