module MaimaiNet
  module Error
    class GeneralError < StandardError
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

    class RequestRetry < StandardError; end
  end
end
