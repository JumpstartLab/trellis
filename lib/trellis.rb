# frozen_string_literal: true

require_relative "trellis/version"
require_relative "trellis/observability"
require_relative "trellis/checkin"

# The fleet's shared decisions, in one place that can be changed once.
#
# Not a framework and not a place for code that merely repeats — a decision
# earns a spot here when we want every app to make it the same way, forever.
# Everything is inert without configuration, so an app can adopt Trellis before
# it adopts any of what Trellis offers.
module Trellis
  class << self
    # Report errors the way the fleet reports errors. Rails apps get this for
    # free through the railtie; call it directly from a plain Ruby entrypoint.
    def install_observability!(**options, &block)
      Observability.install!(**options, &block)
    end

    # Tell the monitor this job finished. Call it at the end of the work.
    def checkin(name)
      Checkin.call(name)
    end
  end
end

require_relative "trellis/railtie" if defined?(::Rails::Railtie)
