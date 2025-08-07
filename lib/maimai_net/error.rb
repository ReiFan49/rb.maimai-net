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
  end
end
