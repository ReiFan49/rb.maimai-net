module MaimaiNet::Model
  module GenericComparison
    refine Array do
      def generic_of?(variants)
        each_with_index.all? do |val, i| variants[i % variants.size] === val end
      end
    end

    refine Hash do
      def generic_of?(variants)
        [keys, values].each_with_index.all? do |li, i|
          li.all? do |val| variants[i % variants.size] === val end
        end
      end
    end
  end

  using GenericComparison

  module Variant
    @class_method = Module.new do
      def [](*args)
        fail ArgumentError, 'no variants given' if args.empty?
        fail ArgumentError, 'variants must be a module or class' if args.any? do |var|
            !(Module === var) && !(Variant === var)
          end

        super
      end
    end

    @class_method.singleton_class.class_exec do
      def to_s
        [Variant.to_s, 'InternalLookupFailsafe'].join('::')
      end
      alias inspect to_s
    end

    def self.included(cls)
      super
      class_method = @class_method
      cls.singleton_class.prepend @class_method
      cls.define_singleton_method :inherited do |subcls|
        super(subcls)
        subcls.singleton_class.prepend class_method
      end if Class === cls
    end

    freeze
  end

  # @!api private
  # defines a generic typing
  class Generic
    include Variant
    include MaimaiNet::CoreExt::MethodCache

    def initialize(cls, variants)
      @class    = cls
      @variants = variants.freeze
      freeze
    end

    cache_method :hash do
      [@class, *@variants].inject(0) do |hsh, type|
        ((hsh >> 11) | type.hash) % (1 << (0.size << 3))
      end
    end

    def ===(obj)
      class_match    = @class === obj
      fail NotImplementedError, "#{obj.class} does not support generic" unless obj.respond_to?(:generic_of?)
      internal_match = obj.generic_of?(variants)

      class_match && internal_match
    end

    def to_s
      "%s[%s]" % [
        to_class.name,
        variants.join(', '),
      ]
    end
    alias inspect to_s

    def to_class
      @class
    end
    def variants
      @variants
    end

    class << self
      private :new

      # defines a generic class statement
      # @return [Generic]
      def [](cls, *variants)
        @_list ||= {}
        gen = @_list.fetch(cls, []).find do |gen_| gen_.variants.eql?(variants) end
        return gen unless gen.nil?

        gen = new(cls, variants)
        (@_list[cls] ||= []) << gen
        gen
      end
    end
  end

  private_constant :GenericComparison
end
