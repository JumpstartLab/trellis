# frozen_string_literal: true

# Required here rather than only in the railtie: observability is usable from a
# plain Ruby entrypoint (a cron, a worker, a script), and a module that calls
# into a library should be the thing that loads it.
require "sentry-ruby"

module Trellis
  # Error reporting, configured the way the fleet has decided to configure it.
  #
  # The value here is not the twenty lines of setup — it is that the five
  # decisions inside them stay identical across every app. Copies of a decision
  # drift the moment one of them is edited, and the edit that matters is usually
  # made under pressure in the app that is currently on fire.
  module Observability
    # Client behaviour, not defects. A 404 is someone asking for something that
    # is not there; a CSRF failure is the protection doing its job. Reporting
    # them trains people to ignore the reports, which is the only real failure
    # mode of an error tracker.
    DEFAULT_EXCLUDED = [
      "ActionController::RoutingError",
      "ActionController::InvalidAuthenticityToken",
      "ActionController::BadRequest",
      "ActionController::UnknownFormat",
      "ActiveRecord::RecordNotFound"
    ].freeze

    class << self
      # Returns true if reporting was configured, false if it was deliberately
      # skipped. Never raises: an app must not fail to boot because the thing
      # that watches it is unhappy.
      def install!(dsn: ENV["SENTRY_DSN"], environment: nil, release: ENV["SENTRY_RELEASE"])
        return false if dsn.nil? || dsn.strip.empty?
        return false unless defined?(::Sentry)

        ::Sentry.init do |config|
          config.dsn = dsn
          config.environment = environment || default_environment
          config.release = release unless release.nil? || release.strip.empty?

          # Errors, not APM. The fleet's problem is silence, not latency — and
          # traces carry request data we have decided not to send.
          config.traces_sample_rate = 0.0

          # In sentry-ruby this single setting gates request bodies, headers and
          # user identity together. It stays false everywhere: several apps here
          # handle client documents, meeting transcripts, or memories, and an
          # error report should say that something broke rather than carry a
          # copy of what was being handled when it did.
          #
          # (The Python SDK splits this across several options.
          # `max_request_body_size` does not exist in Ruby and raises
          # NoMethodError at boot if you port it across.)
          config.send_default_pii = false

          config.excluded_exceptions += DEFAULT_EXCLUDED
          yield config if block_given?
        end

        selftest! if ENV["SENTRY_SELFTEST"].to_s != ""
        true
      rescue StandardError => e
        warn "[trellis] error reporting NOT installed (#{e.class}: #{e.message})"
        false
      end

      # One-shot proof that the path works end to end — SDK loaded, DSN
      # reachable, event accepted, right project. Instrumentation otherwise only
      # proves itself when something is already broken, which is a poor time to
      # discover it was pointed at the wrong project.
      def selftest!(message = "trellis selftest: reporting is live")
        ::Sentry.capture_message(message)
      end

      private

      def default_environment
        return ::Rails.env.to_s if defined?(::Rails) && ::Rails.respond_to?(:env)

        ENV.fetch("RACK_ENV", "development")
      end
    end
  end
end
