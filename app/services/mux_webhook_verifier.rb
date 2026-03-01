require "openssl"

class MuxWebhookVerifier
  DEFAULT_TOLERANCE_SECONDS = 5.minutes

  def self.valid?(header:, payload:, secret:, tolerance: DEFAULT_TOLERANCE_SECONDS, now: Time.current.to_i)
    return false if header.blank? || payload.nil? || secret.blank?

    parsed_header = parse_header(header)
    return false if parsed_header.nil?

    timestamp, provided_signature = parsed_header
    return false if tolerance.present? && (now - timestamp).abs > tolerance

    expected_signature = OpenSSL::HMAC.hexdigest(
      "SHA256",
      secret,
      "#{timestamp}.#{payload}"
    )

    secure_compare(expected_signature, provided_signature)
  end

  def self.parse_header(header)
    components = header.to_s.split(",").each_with_object({}) do |entry, parsed|
      key, value = entry.strip.split("=", 2)
      next if key.blank? || value.blank?

      parsed[key] = value
    end
    timestamp = Integer(components["t"], exception: false)
    signature = components["v1"]

    return nil if timestamp.nil? || signature.blank?

    [timestamp, signature]
  end
  private_class_method :parse_header

  def self.secure_compare(expected, provided)
    return false if expected.bytesize != provided.bytesize

    ActiveSupport::SecurityUtils.secure_compare(expected, provided)
  rescue ArgumentError
    false
  end
  private_class_method :secure_compare
end
