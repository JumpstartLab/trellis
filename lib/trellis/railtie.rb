# frozen_string_literal: true

require "sentry-rails"

module Trellis
  # Wires observability without asking each app for an initializer.
  #
  # A gem that requires a matching initializer in every consumer has only moved
  # the duplication; the point is that adopting Trellis is one line in a Gemfile.
  # Apps that need to add their own excluded exceptions or tags can still call
  # Trellis.install_observability! themselves and set TRELLIS_SKIP_AUTOINSTALL.
  class Railtie < ::Rails::Railtie
    initializer "trellis.observability", before: :load_config_initializers do
      Trellis::Observability.install! unless ENV["TRELLIS_SKIP_AUTOINSTALL"].to_s != ""
    end
  end
end
