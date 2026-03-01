class CreateProcessedWebhookEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :processed_webhook_events do |t|
      t.string :provider, null: false
      t.string :external_event_id, null: false
      t.string :event_type, null: false
      t.datetime :processed_at, null: false

      t.timestamps
    end

    add_index :processed_webhook_events, [ :provider, :external_event_id ], unique: true, name: "index_processed_events_on_provider_and_external_id"
  end
end
