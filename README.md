# Trellis

Shared conventions for Jumpstart Lab's Rails apps, so they can be decided once
instead of copied into each one.

Version 0.1 holds error reporting and heartbeats. Both are inert without
configuration.

## Install

```ruby
gem "trellis", github: "JumpstartLab/trellis"
```

Rails apps need nothing else — a railtie installs error reporting at boot.

## Error reporting

Set `SENTRY_DSN` and reporting turns on. Leave it unset — locally, in tests — and
nothing happens, with no conditional in the app.

The setup is short, but it fixes five decisions in one place:

- **No PII.** In sentry-ruby, `send_default_pii` gates request bodies, headers
  and user identity together, and it stays false. Apps here handle documents,
  transcripts, and personal notes; a report should say that something broke, not
  carry a copy of what was being handled at the time.
- **Errors, not APM.** Traces are off. They carry request data we have chosen not
  to send, and latency is not the problem being solved.
- **404s and CSRF failures are not defects.** Reporting client behaviour trains
  people to ignore reports.
- **Silent without a DSN**, so adoption never requires touching app code twice.
- **A way to prove it works.** `SENTRY_SELFTEST=1` sends one message at boot.
  Set it, deploy, find the event, unset it — otherwise instrumentation only
  proves itself once something is already broken.

Optional: `SENTRY_ENVIRONMENT`, `SENTRY_RELEASE`.

For app-specific additions, set `TRELLIS_SKIP_AUTOINSTALL=1` and call it directly:

```ruby
Trellis.install_observability! do |config|
  config.excluded_exceptions += ["MyApp::ExpectedThing"]
end
```

Note for anyone porting settings from a Python service: `max_request_body_size`
does not exist in sentry-ruby and raises `NoMethodError` at boot.
`send_default_pii = false` covers the same ground.

## Heartbeats

```ruby
Trellis.checkin(:nightly_backup)   # reads TRELLIS_CHECKIN_NIGHTLY_BACKUP
```

Call it at the **end** of the work. A checkin at the start reports that the job
began, which was never in doubt.

Error tracking only sees jobs that run and raise. It cannot see a job that
stopped running, or one that runs and quietly does nothing — so here the job
reports that it finished, and silence is what raises the alarm. No configured
URL means no-op, so the call can be added before the monitor exists.

## Scope

In: conventions we want every app to share, and to change in one place.

Out: deployment config, authorization policy, and anything that would make
upgrading this gem a prerequisite for shipping an app.

## Development

```bash
bundle install
bundle exec ruby -Ilib -Itest test/trellis_test.rb
```
