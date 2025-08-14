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
          optional_keys = props.select do |k, pr|
            Either === pr[:class] &&
            pr[:class].variants.include?(NilClass)
          end.keys

          missing_keys = keys - (kwargs.keys | optional_keys)
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
                                  when Module, Variant
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

    module Chart
      info_base = {
        title: String,
        type: String,
        difficulty: Integer,
      }

      InfoLite = Base::Struct.new(**info_base) do
        def to_info(level_text: '?')
          Info.new(title: title, type: type, difficulty: difficulty, level_text: level_text)
        end
      end

      Info = Base::Struct.new(
        **info_base,
        level_text: String,
      ) do
        def to_lite
          InfoLite.new(title: title, type: type, difficulty: difficulty)
        end
      end

      Song = Base::Struct.new(
        title: String,
        artist: String,
        genre: String,
        jacket: String,
      )
    end

    PhotoUpload = Base::Struct.new(
      info: Chart::InfoLite,
      url: String,
      location: String,
      time: Time,
    )

    module Result
      Progress = Base::Struct.new(
        value: Integer,
        max: Integer,
      ) do
        def to_s; "#{value}/#{max}"; end
        alias to_i value
        alias inspect to_s
      end
    end

    module Record
      History = Base::Struct.new(
        play_count: Integer,
        last_played: Time,
      )

      Score = Base::Struct.new(
        score: Float,
        deluxe_score: Result::Progress,
        grade: Symbol,
        deluxe_grade: Integer,
        flags: Generic[Array, Symbol],
      )

      ChartRecord = Base::Struct.new(
        info: Chart::Info,
        record: Optional[Score],
        history: Optional[History],
      )

      Data = Base::Struct.new(
        info: Chart::Song,
        charts: Generic[Hash, Symbol, ChartRecord],
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
