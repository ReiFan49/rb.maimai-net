module MaimaiNet
  # data model used for parsed data from MaimaiNet::Page
  module Model
    require 'maimai_net/model-typing'

    module Base
      class Struct < ::Struct
        using GenericComparison
        # @param kwargs [Hash] options are strong-typed based on class definition
        def initialize(**kwargs)
          props = self.class.instance_variable_get(:@_properties)
          keys = props.keys
          optional_keys = props.select do |k, pr|
            Either === pr[:class] &&
            pr[:class].variants.include?(NilClass)
          end.keys

          missing_keys = keys - (kwargs.keys | optional_keys)
          fail KeyError, "#{missing_keys.join(', ')} is not defined for #{self.class}" unless missing_keys.empty?
          kwargs.each do |key, value|
            fail KeyError, "#{key} is not defined as struct member" unless keys.include?(key)
            class_str = value.respond_to?(:map_class) ? value.map_class : value.class
            fail TypeError, "#{key} type mismatch, given #{class_str}, expected #{props[key][:class]}" unless props[key][:class] === value
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
        icon: URI::Generic,
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
      WebID = Base::Struct.new(
        item_hash: String,
        item_key: String,
      ) do
        def self.parse(s)
          hash, key = s[0, 128].b, s[128, s.size - 128].unpack1('m*').unpack1('H*')
          new(item_hash: -hash, item_key: -key)
        end

        def to_str
          self.item_hash + [[self.item_key].pack('H*')].pack('m0')
        end
        alias to_s to_str
      end

      class WebID
        DUMMY_ID = -('0' * 128 + 'A' * 44)
        DUMMY = parse(DUMMY_ID)
        def DUMMY.inspect
          '#<%s %s>' % [
            self.class,
            -'dummy',
          ]
        end
      end

      info_base = {
        title: String,
        type: String,
        difficulty: Integer,
      }

      InfoLite = Base::Struct.new(**info_base) do
        def to_info(level_text: '?')
          Info.new(
            web_id: WebID::DUMMY,
            title: title,
            type: type,
            difficulty: difficulty,
            level_text: level_text,
          )
        end
      end

      Info = Base::Struct.new(
        web_id: WebID,
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
        jacket: URI::Generic,
      )
    end

    PhotoUpload = Base::Struct.new(
      info: Chart::InfoLite,
      url: URI::Generic,
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

      TourMember = Base::Struct.new(
        icon: URI::Generic,
        grade: Integer,
        level: Integer,
      )

      Judgment = Base::Struct.new(
        just: Integer,
        perfect: Integer,
        great: Integer,
        good: Integer,
        miss: Integer,
      )

      Offset = Base::Struct.new(
        early: Integer,
        late: Integer,
      )

      Score = Base::Struct.new(
        score: Float,
        deluxe_score: Progress,
        combo: Progress,
        sync_score: Progress,
        grade: Symbol,
        flags: Generic[Array, Symbol],
      )

      Data = Base::Struct.new(
        info: Chart::Info,
        score: Score,
        breakdown: Generic[Hash, Symbol, Judgment],
        timing: Offset,
        members: Generic[Array, TourMember],
      )
    end

    module Record
      History = Base::Struct.new(
        play_count: Integer,
        last_played: Time,
      )

      Score = Base::Struct.new(
        web_id: Chart::WebID,
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
        icon: URI::Generic,
        player_frame: URI::Generic,
        nameplate: URI::Generic,
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
