# frozen_string_literal: true

require "net/http"
require "uri"

module Trellis
  # Heartbeats for scheduled work — the dead man's switch half of monitoring.
  #
  # An error tracker only sees jobs that RUN and raise. It cannot see a job that
  # stopped running, or one that runs and quietly does nothing — a backup script
  # that exits 0 while uploading nothing is invisible to it, and stays invisible
  # for as long as nobody thinks to check.
  #
  # So the contract is inverted. The job says "I finished"; silence is the
  # alert. Call this at the END of the work, never at the start — a checkin at
  # the start reports that the job began, which is the thing that was never in
  # doubt.
  module Checkin
    TIMEOUT = 5 # seconds; a heartbeat must never hold up the work it reports on

    class << self
      # `Trellis.checkin(:nightly_backup)` looks up TRELLIS_CHECKIN_NIGHTLY_BACKUP
      # and pings it. No env var means no monitor is configured, which is a
      # no-op rather than an error — the same inert-by-default rule the error
      # reporting follows, so this is safe to add before the monitor exists.
      #
      # Returns true when the ping was accepted.
      def call(name)
        url = ENV[env_key(name)]
        return false if url.nil? || url.strip.empty?

        ping(url)
      end

      def env_key(name)
        "TRELLIS_CHECKIN_#{name.to_s.upcase.gsub(/[^A-Z0-9]+/, '_')}"
      end

      private

      # Never raises. A monitoring call that can break the job it monitors is a
      # liability, not a safeguard.
      def ping(url)
        uri = URI.parse(url)
        response = Net::HTTP.start(uri.host, uri.port,
                                   use_ssl: uri.scheme == "https",
                                   open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
          http.request(Net::HTTP::Get.new(uri))
        end
        response.is_a?(Net::HTTPSuccess)
      rescue StandardError => e
        warn "[trellis] checkin failed (#{e.class}: #{e.message})"
        false
      end
    end
  end
end
