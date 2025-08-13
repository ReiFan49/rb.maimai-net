module MaimaiNet
  # data model used for parsed data from MaimaiNet::Page
  module Model
    require 'maimai_net/model-typing'

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

    PhotoUpload = Base::Struct.new(
      chart_type: String,
      difficulty: Integer,
      title: String,
      url: String,
      location: String,
      time: Time,
    )

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
