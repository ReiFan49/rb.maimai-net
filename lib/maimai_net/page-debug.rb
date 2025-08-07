module MaimaiNet
  module Page
    class Debug < Base
      def debug
        byebug
      end
    end if respond_to? :byebug
  end
end
