require 'ddtrace/contrib/configuration/settings'
require 'ddtrace/contrib/resque/ext'

module Datadog
  module Contrib
    module Resque
      module Configuration
        # Custom settings for the Resque integration
        class Settings < Contrib::Configuration::Settings
          option  :analytics_enabled,
                  default: -> { env_to_bool(Ext::ENV_ANALYTICS_ENALBED, nil) },
                  lazy: true

          option  :analytics_sample_rate,
                  default: -> { env_to_float(Ext::ENV_ANALYTICS_SAMPLE_RATE, 1.0) },
                  lazy: true

          option :service_name, default: Ext::SERVICE_NAME
          option :workers, default: []
        end
      end
    end
  end
end
