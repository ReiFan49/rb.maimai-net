module MaimaiNet
  module Error
    class BaseError < StandardError
      def maintenance?; false; end
    end
    class ClientError < BaseError; end
    class ServerError < BaseError; end

    class GeneralError < ServerError
      def initialize(code)
        super("Error #{code}")
        @code = code
      end
      attr_reader :code
    end

    class LoginError < GeneralError; end
    class SessionError < GeneralError; end
    # This error is finnicky.
    # Basically if this will happen when logging into non-home url
    # either from previous cookie or through the provided callback.
    class SessionRefreshError < SessionError
      def initialize(code)
        super
        StandardError.instance_method(__method__).bind(self).call('Please access main page before accessing other pages.')
      end
    end
    class SessionExpiredError < SessionError; end

    class RequestRetry < ClientError; end
    class RetryExhausted < ClientError; end

    module Maintenance
      def maintenance?
        true
      end
    end
    class RoutineMaintenance < ClientError
      include Maintenance
      def initialize(time_range)
        start_time, end_time = time_range.start, time_range.end
        super("Maintenance from %s to %s." % [
          start_time.strftime('%H:%M'),
          end_time.strftime('%H:%M'),
        ])

        @start_time = start_time
        @end_time   = end_time
      end

      attr_reader :start_time, :end_time
    end
    class UnderMaintenance < ServerError; include Maintenance end
  end
end
