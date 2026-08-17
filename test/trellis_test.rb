# frozen_string_literal: true

require "minitest/autorun"
require "trellis"

# The tests worth having here are about the DECISIONS, since that is what the
# gem exists to hold. Whether sentry-ruby can send an event is sentry-ruby's
# problem; whether we send PII is ours.
class TrellisObservabilityTest < Minitest::Test
  def setup
    @original = ENV.to_h.slice("SENTRY_DSN", "SENTRY_SELFTEST", "SENTRY_RELEASE")
    %w[SENTRY_DSN SENTRY_SELFTEST SENTRY_RELEASE].each { |k| ENV.delete(k) }
  end

  def teardown
    %w[SENTRY_DSN SENTRY_SELFTEST SENTRY_RELEASE].each { |k| ENV.delete(k) }
    @original.each { |k, v| ENV[k] = v }
  end

  # Inert by default is what makes the gem adoptable before the monitoring is.
  # An app should be able to add Trellis and deploy with nothing configured.
  def test_no_dsn_is_a_no_op_not_an_error
    refute Trellis::Observability.install!(dsn: nil)
    refute Trellis::Observability.install!(dsn: "")
    refute Trellis::Observability.install!(dsn: "   ")
  end

  def test_install_configures_the_fleet_decisions
    captured = nil
    Trellis::Observability.install!(dsn: "https://k@example.invalid/1", environment: "test") do |config|
      captured = config
    end

    refute_nil captured, "the block should receive the config for app-specific additions"
    assert_equal false, captured.send_default_pii, "PII must never be sent"
    assert_equal 0.0, captured.traces_sample_rate, "errors, not APM"
    assert_equal "test", captured.environment
    Trellis::Observability::DEFAULT_EXCLUDED.each do |name|
      assert_includes captured.excluded_exceptions, name
    end
  end

  # A blank SENTRY_RELEASE must not become a release literally named "" — that
  # sorts oddly in the UI and tells you nothing about which deploy broke.
  #
  # Leaving it unset does NOT mean nil: sentry-ruby auto-detects a release from
  # git or the environment, which is a better answer than anything we would
  # invent. So the decision under test is "never record an empty one", not
  # "never record one".
  def test_blank_release_never_becomes_an_empty_release
    captured = nil
    Trellis::Observability.install!(dsn: "https://k@example.invalid/1", release: "") { |c| captured = c }

    refute_equal "", captured.release
  end

  # Reporting must never be the reason an app fails to boot.
  def test_install_never_raises
    broken = Object.new
    def broken.strip = raise("boom")

    assert_silent_failure { Trellis::Observability.install!(dsn: broken) }
  end

  private

  def assert_silent_failure
    result = nil
    _out, err = capture_io { result = yield }
    refute result, "a failed install returns false"
    assert_match(/trellis/, err, "and says so on stderr — silence is the failure mode we are fixing")
  end
end

class TrellisCheckinTest < Minitest::Test
  def teardown
    ENV.delete("TRELLIS_CHECKIN_NIGHTLY_BACKUP")
  end

  def test_env_key_derivation
    assert_equal "TRELLIS_CHECKIN_NIGHTLY_BACKUP", Trellis::Checkin.env_key(:nightly_backup)
    assert_equal "TRELLIS_CHECKIN_NIGHTLY_BACKUP", Trellis::Checkin.env_key("nightly-backup")
  end

  # Same rule as the DSN: a job can call checkin before anyone has created the
  # monitor, and nothing happens until the monitor exists.
  def test_unconfigured_monitor_is_a_no_op
    refute Trellis.checkin(:nightly_backup)
  end

  def test_unreachable_monitor_does_not_raise
    ENV["TRELLIS_CHECKIN_NIGHTLY_BACKUP"] = "https://127.0.0.1:1/never"

    result = nil
    _out, err = capture_io { result = Trellis.checkin(:nightly_backup) }

    refute result
    assert_match(/checkin failed/, err)
  end
end
