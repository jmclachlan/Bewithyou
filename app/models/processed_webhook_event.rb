class ProcessedWebhookEvent < ApplicationRecord
  validates :provider, :external_event_id, :event_type, :processed_at, presence: true

  def self.claim!(provider:, external_event_id:, event_type:)
    create!(
      provider: provider,
      external_event_id: external_event_id,
      event_type: event_type,
      processed_at: Time.current
    )

    true
  rescue ActiveRecord::RecordNotUnique
    false
  end
end
