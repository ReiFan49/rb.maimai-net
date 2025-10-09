module MaimaiNet
  module Page
    # Interesting on how refinement ON this file affects the use of helper_method block invocation.
    using IncludeAutoConstant

    # @!api private
    # scope extension to add various html-related method
    class HelperBlock < ::BasicObject
      include ModuleExt

      # copies page instance variables
      # @param page [Page::Base] page object tp refer
      def initialize(page)
        page.instance_variables.map do |k|
          "#{k} = page.instance_variable_get(#{k.inspect})"
        end.join($/).tap do |expr|
          instance_eval expr, __FILE__, __LINE__ + 1
        end if Page::Base === page

        @_page = page
      end

      # proxy method
      private
      def method_missing(meth, *args, **kwargs, &block)
        return super unless Page::Base === @_page
        kwargs.empty? ?
          @_page.__send__(meth, *args, &block) :
          @_page.__send__(meth, *args, **kwargs, &block)
      end

      # checks whether current or proxied object have respective method.
      # @return [Boolean]
      def respond_to_missing?(meth, priv=false)
        return super unless Page::Base === @_page
        super or @_page.respond_to?(meth, priv)
      end

      GROUPED_INTEGER = /0|[1-9](?:[0-9]*(?:,[0-9]+)*)/.freeze
      GROUPED_FREE_INTEGER = /\d+(?:,\d+)*/.freeze

      [[::Kernel, %i(method)]].each do |cls, methods|
        methods.each do |meth|
          define_method meth, cls.instance_method(meth)
        end
      end

      private
      # @return [String] stripped text content
      def strip(node); node&.content.strip; end
      # @return [String] src attribute of the element
      def src(node); node['src']; end
      # @return [Integer] de-grouped the integer string
      def int(str); str.gsub(',', '').to_i(10); end
      # scan for the first number-string found on given string
      # and de-group the number-string into an actual integer
      # @return [Integer]
      # @see #int
      def get_int(content); int(GROUPED_INTEGER.match(content).to_s); end
      # (see #get_int)
      # @note This version retrieves potentially padded integer as well.
      def get_fullint(content); int(GROUPED_FREE_INTEGER.match(content).to_s); end
      # scan for all number-string found on given string
      # and de-group all of the string into array of integers
      # @return [Array<Integer>]
      def scan_int(content); content.scan(GROUPED_INTEGER).map(&method(:int)); end
      # parse time string as JST
      # @return [Time]
      def jst(time); ::Time.strptime(time + ' +09:00', '%Y/%m/%d %H:%M %z'); end
      # parse time string as JST from stripped text content
      # @return [Time]
      def jst_from(node); jst(strip(node)); end

      inspect_permit_variable_exclude :_page
      inspect_permit_expression do |value| false end
    end

    class << HelperBlock
      private :new
    end

    module TrackHelper
      # @return [Constants::Difficulty] difficulty value of given html element
      def get_chart_difficulty_from(node)
        Difficulty(::Kernel.Pathname(src(node)).sub_ext('').sub(/.+_/, '').basename)
      end

      # @return [String] chart type of given html element
      # @return ["unknown"] if the chart element is not defined
      def get_chart_type_from(node)
        return -'unknown' if node.nil?

        ::Kernel.Pathname(::Kernel.URI(src(node)).path).sub_ext('').sub(/.+_/, '').basename.to_s
      end

      # @return [String] chart variant of given html element
      # @return [nil]    if the chart element is not utage
      # @see HelperBlock#strip
      # @note this is a semantic clarity for strip function.
      def get_chart_variant_from(node)
        return if node.nil?

        strip(node)
      end
    end

    HelperBlock.include TrackHelper

    # adds capability to inject methods using hidden helper block
    module HelperSupport
      # defines the method to be injected with hidden helper block.
      # such method have an extended set of capability to use methods
      # provided on HelperBlock class.
      # @param meth [Symbol]
      # @return [Symbol]
      def helper_method(meth, &block)
        lock :helper_method, meth do
          define_method meth do
            HelperBlock.__send__(:new, self).instance_exec(&block)
          end
        end
      end

      # install an auto-hook for data method for any Page::Base class.
      # @param meth [Symbol]
      # @return [void]
      def method_added(meth)
        return super unless meth === :data && self <= Page::Base

        lock :helper_method, meth do
          fail NotImplementedError, "no solution found for method definition rebinding. please use helper_method #{meth.inspect} do ... end block instead."

          # rand_name = '_%0*x' % [0.size << 1, rand(1 << (0.size << 3))]
          old_meth = instance_method(meth)
          # obj = allocate
          # old_meth = obj.method(meth)
          # HelperBlock.define_method rand_name, old_meth
          # old_meth = instance_method(rand_name)
          # p old_meth
          # remove_method rand_name

          define_method meth do
            HelperBlock.__send__(:new, self).instance_exec(&old_meth.bind(self))
          end
          super
        end
      end

      # automatically install mutex upon invoked for an extension
      # @return [void]
      def self.extended(cls)
        cls.class_exec do
          include ModuleExt::AddInternalMutex
        end
      end
    end

    private_constant :HelperBlock

    class Base
      extend HelperSupport
    end
  end
end
