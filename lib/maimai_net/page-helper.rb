module MaimaiNet
  module Page
    class HelperBlock < ::BasicObject
      include CoreExt

      # copies page instance variables
      # @param page [Page::Base] page object tp refer
      def initialize(page)
        page.instance_variables.map do |k|
          "#{k} = page.instance_variable_get(#{k.inspect})"
        end.join($/).tap do |expr|
          instance_eval expr, __FILE__, __LINE__ + 1
        end

        @_page = page
      end

      # proxy method
      private
      def method_missing(meth, *args, **kwargs, &block)
        kwargs.empty? ?
          @_page.__send__(meth, *args, &block) :
          @_page.__send__(meth, *args, **kwargs, &block)
      end

      def respond_to_missing?(meth, priv=false)
        super or @_page.respond_to?(meth, priv)
      end

      GROUPED_INTEGER = /0|[1-9](?:[0-9]*(?:,[0-9]+)*)/

      [[::Kernel, %i(method)]].each do |cls, methods|
        methods.each do |meth|
          define_method meth, cls.instance_method(meth)
        end
      end

      private
      def helper; end
      def strip(node); node&.content.strip; end
      def src(node); node['src']; end
      def int(str); str.gsub(',', '').to_i(10); end
      def get_int(content); int(GROUPED_INTEGER.match(content).to_s); end
      def scan_int(content); content.scan(GROUPED_INTEGER).map(&method(:int)); end

      inspect_permit_variable_exclude :_page
      inspect_permit_expression do |value| false end
    end

    class << HelperBlock
      private :new
    end

    module HelperSupport
      def helper_method(meth, &block)
        lock :helper_method, meth do
          define_method meth do
            HelperBlock.__send__(:new, self).instance_exec(&block)
          end
        end
      end

      def method_added(meth)
        if meth === :data then
          lock :helper_method, meth do
            old_meth = instance_method(meth)
            define_method meth do
              HelperBlock.__send__(:new, self).instance_exec(&old_meth.bind(self))
            end
          end
        end

        super
      end

      def self.extended(cls)
        cls.class_exec do
          include CoreExt::AddInternalMutex
        end
      end
    end

    class Base
      extend HelperSupport
    end
  end
end
