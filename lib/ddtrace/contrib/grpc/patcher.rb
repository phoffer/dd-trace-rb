require 'ddtrace/contrib/patcher'
require 'ddtrace/contrib/grpc/ext'

module Datadog
  module Contrib
    module GRPC
      # Patcher enables patching of 'grpc' module.
      module Patcher
        include Contrib::Patcher

        module_function

        def patched?
          done?(:grpc)
        end

        def patch
          do_once(:grpc) do
            begin
              require 'ddtrace/propagation/grpc_propagator'
              require 'ddtrace/contrib/grpc/datadog_interceptor'
              require 'ddtrace/contrib/grpc/intercept_with_datadog'

              add_pin!

              # TODO: When GRPC pin is removed, set service info.
              # get_option(:tracer).set_service_info(
              #   get_option(:service_name),
              #   Ext::APP,
              #   Datadog::Ext::AppTypes::WEB
              # )

              prepend_interceptor
            rescue StandardError => e
              Datadog::Tracer.log.error("Unable to apply gRPC integration: #{e}")
            end
          end
        end

        def add_pin!
          DeprecatedPin.new(
            get_option(:service_name),
            app: Ext::APP,
            app_type: Datadog::Ext::AppTypes::WEB,
            tracer: get_option(:tracer)
          ).onto(::GRPC)
        end

        def prepend_interceptor
          ::GRPC::InterceptionContext
            .send(:prepend, Datadog::Contrib::GRPC::InterceptWithDatadog)
        end

        def get_option(option)
          Datadog.configuration[:grpc].get_option(option)
        end

        # Implementation of deprecated Pin, which raises warnings when accessed.
        # To be removed when support for Datadog::Pin with GRPC is removed.
        class DeprecatedPin < Datadog::Pin
          include Datadog::DeprecatedPin

          DEPRECATION_WARNING = %(
            Use of Datadog::Pin with GRPC is DEPRECATED.
            Upgrade to the configuration API using the migration guide here:
            https://github.com/DataDog/dd-trace-rb/releases/tag/v0.11.0).freeze

          def tracer=(tracer)
            Datadog.configuration[:grpc][:tracer] = tracer
          end

          def service_name=(service_name)
            Datadog.configuration[:grpc][:service_name] = service_name
          end

          def log_deprecation_warning(method_name)
            do_once(method_name) do
              Datadog::Tracer.log.warn("#{method_name}:#{DEPRECATION_WARNING}")
            end
          end
        end
      end
    end
  end
end
