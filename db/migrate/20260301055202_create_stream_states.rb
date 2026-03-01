class CreateStreamStates < ActiveRecord::Migration[8.1]
  def change
    create_table :stream_states do |t|
      t.boolean :live, null: false, default: false
      t.string :live_playback_id
      t.string :vod_playback_id
      t.string :last_event_id
      t.datetime :sent_live_email_at
      t.datetime :sent_replay_email_at

      t.timestamps
    end

    add_index :stream_states, :last_event_id
  end
end
