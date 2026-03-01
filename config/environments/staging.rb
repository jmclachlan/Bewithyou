require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Staging should be close to production while still easy to debug.
  config.enable_reloading = false
  # Keep eager loading off so staging boots cleanly without production-only adapters.
  config.eager_load = false
  config.consider_all_requests_local = false

  config.action_controller.perform_caching = true
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.day.to_i}" }

  config.active_storage.service = :local

  config.log_tags = [ :request_id ]
  config.logger = ActiveSupport::TaggedLogging.logger(STDOUT)
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")
  config.silence_healthcheck_path = "/up"

  config.active_support.report_deprecations = false
  config.i18n.fallbacks = true
  config.active_record.dump_schema_after_migration = false
  config.active_record.attributes_for_inspect = [ :id ]

  config.action_mailer.default_url_options = { host: ENV.fetch("APP_HOST", "watch.example.com") }
end
