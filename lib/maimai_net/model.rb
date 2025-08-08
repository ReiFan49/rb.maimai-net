module MaimaiNet
  # data model used for parsed data from MaimaiNet::Page
  module Model
    # @!api private
    # defines a generic typing
    class Generic
      include CoreExt::MethodCache

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
        internal_match = if ::Array == @class then
                           obj.each_with_index.all? do |val, i| variants[i % variants.size] === val end
                         elsif ::Hash == @class then
                           [obj.keys, obj.values].each_with_index.all? do |li, i|
                             li.all? do |val| variants[i % variants.size] === val end
                           end
                         else
                           fail NotImplementedError, "#{obj.class} does not support generic" unless obj.respond_to?(:generic_of?)
                           obj.generic_of?(variants)
                         end

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
          fail ArgumentError, 'no variants given' if variants.empty?
          fail ArgumentError, 'variants must be a module or class' if variants.any? do |var| !(Module === var) end

          @_list ||= {}
          gen = @_list.fetch(cls, []).find do |gen_| gen_.variants.eql?(variants) end
          return gen unless gen.nil?

          gen = new(cls, variants)
          (@_list[cls] ||= []) << gen
          gen
        end
      end
    end

    module Base
      class Struct < ::Struct
        # @param kwargs [Hash] options are strong-typed based on class definition
        def initialize(**kwargs)
          props = self.class.instance_variable_get(:@_properties)
          keys = props.keys

          missing_keys = keys - kwargs.keys
          fail KeyError, "#{missing_keys.join(', ')} not defined" unless missing_keys.empty?
          kwargs.each do |key, value|
            fail KeyError, "#{key} is not defined as struct member" unless keys.include?(key)
            fail TypeError, "#{key} type mismatch, given #{value.class}, expected #{props[key][:class]}" unless props[key][:class] === value
          end

          args = kwargs.values_at(*keys)
          super(*args)
        end
      end
      class << Struct
        # creates a strong-typed struct data
        # @param  opts [Hash{Symbol => Module}]
        #   list of struct members along with respective type definition
        # @return [Struct] new subclass with defined types
        def new(**opts, &block)
          super(*opts.keys) do
            @_properties = {}
            opts.each do |key, typedata|
              @_properties[key] = case typedata
                                  when Array
                                    {class: Generic[*typedata]}
                                  when Module, Generic
                                    {class: typedata}
                                  else
                                    fail TypeError, "invalid type definition"
                                  end
            end

            class_exec(&block) if block_given?
          end
        end
      end
    end

    SongCount = Base::Struct.new(achieved: Integer, total: Integer) do
      def to_s
        "#{achieved}/#{total}"
      end
      alias inspect to_s
    end

    module PlayerCommon
      Info = Base::Struct.new(
        name: String,
        title: String,
        grade: String,
      )
    end

    module PlayerData
      Decoration = Base::Struct.new(
        icon: String,
      )
      ExtendedInfo = Base::Struct.new(
        rating: Integer,
        class_grade: String,
        partner_star_total: Integer,
      )

      DifficultyStatistic = Base::Struct.new(
        clears: SongCount,
        ranks: Generic[Hash, Symbol, SongCount],
        dx_ranks: Generic[Hash, Integer, SongCount],
        flags: Generic[Hash, Symbol, SongCount],
        sync_flags: Generic[Hash, Symbol, SongCount],
      )

      InfoPlate = Base::Struct.new(
        info: PlayerCommon::Info,
        decoration: Decoration,
        extended: ExtendedInfo,
      )
      Data = Base::Struct.new(
        plate: InfoPlate,
        statistics: Generic[Hash, Symbol, DifficultyStatistic],
      )
    end

    module FinaleArchive
      Decoration = Base::Struct.new(
        icon: String,
        player_frame: String,
        nameplate: String,
      )
      Currency = Base::Struct.new(
        amount: Integer, piece: Integer, parts: Integer,
      )
      ExtendedInfo = Base::Struct.new(
        rating: Float, rating_highest: Float,
        region_count: Integer,
        currency: Currency,
        partner_level_total: Integer,
      )

      DifficultyStatistic = Base::Struct.new(
        total_score: Integer,
        clears: SongCount,
        ranks: Generic[Hash, Symbol, SongCount],
        flags: Generic[Hash, Symbol, SongCount],
        sync_flags: Generic[Hash, Symbol, SongCount],
        multi_flags: Generic[Hash, Symbol, SongCount],
      )

      Data = Base::Struct.new(
        info:       PlayerCommon::Info,
        decoration: Decoration,
        extended:   ExtendedInfo,

        statistics: Generic[Hash, Symbol, DifficultyStatistic],
      )
    end

    private_constant :Base
  end
end
