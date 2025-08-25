require 'faraday'
require 'faraday/follow_redirects'
require 'nokogiri'

require 'maimai_net/page'
require 'maimai_net/faraday_ext/cookie_jar'

module MaimaiNet
  module Client
    using IncludeDifficulty

    class Base
      include CoreExt

      def initialize(username = nil, password = nil)
        @username = username
        @password = password
        @cookies  = HTTP::CookieJar.new
      end

      attr_reader :username, :password, :cookies
      inspect_permit_variable_exclude :username, :password, :cookies
    end

    class << Base
      def inherited(cls)
        super

        return unless self.singleton_class == method(__method__).owner
        @_subclasses ||= []
        @_subclasses << cls unless @_subclasses.include?(cls)

        cls.singleton_class.undef_method :regions
      end

      def regions
        fail NoMethodError, "invalid call" unless self == method(__method__).owner
        @_subclasses.dup
      end

      def region_info
        fail NotImplementedError, "this client is not associated with region information" if (@_properties.to_h rescue {}).empty?
        @_properties.dup
      end
    end

    class Connection
      # @param client [Base] client data
      def initialize(client)
        @client = client
        @conn   = nil
      end

      # automatically private hook methods
      # @return [void]
      def self.method_added(meth)
        return super unless /^on_/.match? meth
        private meth
      end

      # @!group Routes
      public
      # access home page
      # @return [void]
      def home
        send_request('get', '/maimai-mobile/home', nil)
      end

      # logs out current session
      # @return [void]
      def logout
        send_request('get', '/maimai-mobile/home/userOption/logout', nil)
      end

      # access player data
      # @param diffs [Array<String, Symbol, Integer, MaimaiNet::Difficulty>] valid difficulty values
      # @return [Model::PlayerData::Data] player's maimai deluxe difficulty statistics
      # @raise [TypeError] invalid difficulty provided
      # @raise [ArgumentError] no difficulty provided
      def player_data(*diffs)
        diffs.compact!
        diffs.uniq!
        fail ArgumentError, "expected at least 1, given #{diffs.size}" if diffs.empty?

        diff_errors = []
        diffs.reject do |diff|
          case diff
          when String, Symbol
            MaimaiNet::Difficulty::DELUXE_WEBSITE.key?(diff.to_sym) ||
            MaimaiNet::Difficulty::DELUXE_WEBSITE.key?(Difficulty::SHORTS.key(diff.to_sym))
          when MaimaiNet::Difficulty # always true
            true
          when Integer
            MaimaiNet::Difficulty::DELUXE_WEBSITE.value?(diff)
          else
            false
          end
        end.each do |diff|
          case diff
          when String, Symbol; diff_errors << [diff, KeyError]
          when Integer;        diff_errors << [diff, ArgumentError]
          else;                diff_errors << [diff, TypeError]
          end
        end

        unless diff_errors.empty?
          fail TypeError, "at least one of difficulty provided are erroneous.\n%s" % [
            diff_errors.map do |d, et| '(%s: %p)' % [et, d] end.join(', '),
          ]
        end

        diffs.map! do |diff|
          case diff
          when String, Symbol;        Difficulty(diff)
          when MaimaiNet::Difficulty; diff
          when Integer;               Difficulty(deluxe_web_id: diff)
          end
        end
        diffs.sort_by! &:id

        results = diffs.map do |diff|
          send_request(
            'get', '/maimai-mobile/playerData',
            {diff: diff.deluxe_web_id},
            response_page: Page::PlayerData,
          )
        end

        # aggregate results if necessary
        if results.size > 1 then
          user_diff_stat = {}
          results.each do |result|
            user_diff_stat.update result.statistics
          end
          results.first.class.new(
            plate: results.first.plate,
            statistics: user_diff_stat,
          )
        else
          results.shift
        end
      end

      # access recently uploaded photo album page
      # @return [Array<Model::PhotoUpload>] player's recently uploaded photos
      def photo_album
        send_request(
          'get', '/maimai-mobile/playerData/photo', nil,
          response_page: Page::PhotoUpload,
        )
      end

      # access recent session gameplay info
      # @return [Array<Model::Result::TrackReference>]
      def recent_plays
        send_request(
          'get', '/maimai-mobile/record', nil,
          response_page: Page::RecentTrack,
        )
      end

      # access recent session gameplay info detail
      # @return [Model::Result::Data]
      def recent_play_info(ref)
        id = case ref
             when Model::Result::TrackReference
               ref.ref_web_id.to_s
             when Model::Result::ReferenceWebID
               ref.to_s
             when /^\d+,\d+$/
               ref
             else
               fail TypeError, 'expected a valid index ID format'
             end

        send_request(
          'get', '/maimai-mobile/record/playlogDetail', {idx: id},
          response_page: Page::TrackResult,
        )
      end

      # access given set best score
      # @return [Model::Record::Data]
      def music_record_info(ref)
        id = case ref
             when Model::Chart::WebID::DUMMY, Model::Chart::WebID::DUMMY_ID
               fail ArgumentError, 'unable to use dummy ID for lookup'
             when Model::Chart::WebID
               ref.to_s
             when String
               ref
             else
               fail TypeError, 'expected a valid index ID format'
             end

        send_request(
          'get', '/maimai-mobile/record/musicDetail', {idx: id},
          response_page: Page::ChartsetRecord,
        )
      end

      # access finale archive page
      # @return [Model::FinaleArchive::Data] player's archived maimai finale statistics
      def finale_archive
        send_request(
          'get', '/maimai-mobile/home/congratulations', nil,
          response_page: Page::FinaleArchive,
        )
      end

      # @!endgroup

      # @!group Hooks

      # hook upon receiving a login page
      # @return [void]
      def on_login_request(url, body, **opts)
        page = Nokogiri::HTML.parse(body)
        form = page.at_css('form[action][method=post]:has(input[type=password])')
        data = form.css('input').select do |elm|
          %w(text password hidden).include? elm['type'].downcase
        end.map do |elm|
          [elm['name'], elm['value']]
        end.inject({}) do |res, (name, value)|
          res[name] = value
          res
        end

        userkey = if data.key?('segaId') then 'segaId'
                  elsif data.key?('sid') then 'sid'
                  else fail NotImplementedError, 'user id compatible field not found'
                  end

        data[userkey]    = @client.username
        data['password'] = @client.password

        send_request(
          form['method'],
          url + form['action'],
          data, **opts,
        )
      end

      # hook upon receiving login error page
      # @return [void]
      # @raise [Error::LoginError]
      def on_login_error
        fail Error::LoginError, 100101
      end

      # hook upon receiving generic error page
      # @return [void]
      # @raise [Error::LoginError] error code describes an invalid login
      # @raise [Error::SessionRefreshError] error code describes a vague request to visit homepage
      # @raise [Error::SessionExpiredError] error code describes the session is fully expired and requires another login
      # @raise [Error::GeneralError]
      def on_error(body)
        page = Nokogiri::HTML.parse(body)
        error_elm = page.at_css('.container_red > div')
        error_note = error_elm.text
        error_code = error_note.match(/\d+/).to_s.to_i

        case error_code
        when 100101
          fail Error::LoginError, error_code
        when 200002
          fail Error::SessionRefreshError, error_code
        when 200004
          fail Error::SessionExpiredError, error_code
        else
          fail Error::GeneralError, error_code
        end
      end

      # @!endgroup

      # @abstract sends request to given connection object
      # @param method [Symbol, String] request method
      # @param url    [URI]            request path
      # @param data   [String, Object] request body
      # @param opts   [Hash{Symbol => Object}]
      # @option response_page [Class<Page::Base>]  a callback to convert response into a page object
      # @return [Model::Base::Struct] returns page data based from provided response_page field
      # @return [void]
      def send_request(method, url, data, **opts)
        fail NotImplementedError, 'abstract method called' if Connection == method(__method__).owner
      end

      private
      # @!api private
      # @param url  [URI] response url
      # @param body [String] response body
      # @return [Model::Base::Struct, Array<Model::Base::Struct>] response page handled result
      # @return [nil] no response page defined to handle the response
      def process_response(url:, body:, request_options:)
        info = @client.class.region_info

        if info.key?(:login_error_proc) && info[:login_error_proc].call(url, body) then
          return on_login_error
        elsif url == URI.join(info[:website_base], info[:website_base].path + '/', 'error/') then
          return on_error(body)
        elsif info[:login_page_proc].call(url) then
          return on_login_request(url, body, **request_options)
        end

        if Class === request_options[:response_page] && request_options[:response_page] < Page::Base then
          return request_options[:response_page].parse(body).data
        end

        nil
      end
    end

    # Provides capability to handle the connection wrapping.
    module ConnectionProvider
      # @overload new(*args)
      #   First form, pass the remaining arguments into #initialize and wrap it into a connection.
      #   @return [Connection] default connection
      # @overload new(key, *args)
      #   Second form, use mapped connection name to retrieve the connection,
      #     pass remaining arguments into #initialize and wrap it into a connection.
      #   @param key [Symbol] client connection name to use
      #   @return [Connection] provided connection from given key
      # @overload new(cls, *args)
      #   Third form, use given class as connection,
      #     pass remaining arguments into #initialize and wrap it into a connection.
      #   @param cls [Class<Connection>] client connection class to use
      #   @return [Connection] provided connection
      #   @raise [ArgumentError] provided class is not a Connection.
      # @raise [ArgumentError] invalid form.
      def new(sym_or_cls = nil, *args, &block)
        return method(__method__).call(nil, sym_or_cls, *args, &block) if String === sym_or_cls
        sym_or_cls = self.default_connection if sym_or_cls.nil?

        case sym_or_cls
        when Symbol
          cls = connections[sym_or_cls]
        when Class
          cls = sym_or_cls
          fail ArgumentError, "expected Connection class, given #{cls}" unless cls < Connection
        else
          fail ArgumentError, "expected a connection name or a Connection-subclass, given #{sym_or_cls.class}"
        end

        cls.new(super(*args, &block))
      end

      # @param key [Symbol] connection name
      # @param cls [Class<Connection>] connection class
      # @return [void]
      # @raise [ArgumentError] provided class is not a Connection.
      def register_connection(key, cls)
        fail ArgumentError, "expected Connection class, given #{cls}" unless cls < Connection
        key = String(key).to_sym
        connections.store(key, cls)
        self.default_connection = key if connections.size.pred.zero?
        nil
      end

      # @return [Symbol, nil] currently assigned default connection for clients
      def default_connection
        class_variable_get(:@@default_connection)
      end

      # @param key [Symbol] connection name
      # @return [void]
      # @raise [KeyError] provided key is not a registered connection.
      def default_connection=(key)
        key = String(key).to_sym
        fail KeyError, "'#{key}' is not registered" unless connections.key?(key)
        class_variable_set(:@@default_connection, key)
        nil
      end

      private
      # @return [Hash{Symbol => Class<Connection>}] set of key to connection class mappings
      def connections
        class_variable_get(:@@connections)
      end

      # initializes connection class variables
      # @return [void]
      def self.extended(cls)
        super

        cls.class_eval <<~EOT, __FILE__, __LINE__ + 1
          @@default_connection = nil
          @@connections = {}
        EOT
      end
    end

    module ConnectionProtocol
      # wraps connection method definition with auto-retry capability
      # @param opts [Hash]
      # @option retry_count [Integer] set maximum allowed retries within this retry block
      # @raise [Error::RetryExhausted] upon attempting to exceed the allowed amount of
      #   attempts for retrying the request.
      def send_request(method, url, data, **opts)
        fail NotImplementedError, 'connection is not defined' if @conn.nil?

        # skip the wrapping if had been called recently
        # * does not take account on "hooked" calls
        prependers = self.class.ancestors
        prependers.slice! (prependers.index(self.class)..)

        stack = caller_locations(1).select do |trace| __method__.id2name == trace.label end.first(prependers.size)
        if stack.size > 0 then
          prev = stack[prependers.reverse.index(ConnectionProtocol)]
          return super if __method__.id2name == prev.label # do not wrap further if it's a super call
        end

        max_count = retry_count = Integer === opts[:retry_count] ? opts[:retry_count] : 3
        begin
          super
        rescue Error::RequestRetry
          retry_count -= 1
          retry unless retry_count.negative?
          fail Error::RetryExhausted, "attempt exceeds #{max_count} retries"
        end
      end
    end

    module ConnectionMaintenanceSafety
      # @return [Range(Time, Time)] JST's today maintenance schedule (in local time).
      def maintenance_period
        ctime = Time.now
        atime = ctime.dup.localtime(32400)
        start_mt = Time.new(
          atime.year, atime.month, atime.day,
          4, 0, 0, atime.utc_offset,
        ).localtime(ctime.utc_offset)
        (start_mt)...(start_mt + 10_800)
      end

      # prevents connection during maintenance period.
      # @raise [Error::RoutineMaintenance] raised if invoked during maintenance period.
      def send_request(method, url, data, **opts)
        ctime = Time.now
        period = maintenance_period
        fail Error::RoutineMaintenance, period if period.include?(ctime)

        super
      end
    end

    module ConnectionSupportSongList
      using ObjectAsArray

      # access user's best scores of all music on given sorting mode
      # @param options [Hash] query parameter
      # @option genre     [Integer, Constants::Genre]
      # @option character [Integer, Constants::NameGroup]
      # @option level     [Integer, Constants::LevelGroup]
      # @option version   [Integer, Symbol, Constants::GameVersion]
      # @option diff      [Integer, Constants::Difficulty]
      # @return [Hash{Symbol => Array<Model::Record::InfoRating>}]
      def song_list(category, **options)
        fail ArgumentError, "#{category} is not a valid key" unless /^[A-Z][a-z]+(?:[A-Z][a-z]+)*$/.match?(category)

        converted_options = options.map do |key, value|
          next [key, value] unless Symbol === value
          raw_value = case key
                      when :diff;      MaimaiNet::Difficulty.new(value)
                      when :genre;     MaimaiNet::Genre.new(value)
                      when :character; MaimaiNet::NameGroup.new(value)
                      when :level;     MaimaiNet::LevelGroup.new(value)
                      when :version;   MaimaiNet::GameVersion.new(value)
                      end
          [key, raw_value]
        end.to_h

        options.update(converted_options)

        options.transform_values! do |value|
          case value
          when MaimaiNet::Genre, MaimaiNet::NameGroup, MaimaiNet::LevelGroup, MaimaiNet::GameVersion, MaimaiNet::Difficulty
            value.deluxe_web_id
          else
            value
          end
        end

        send_request(
          'get', "/maimai-mobile/record/music#{category}/search", options,
          response_page: Page::MusicList,
        )
      end

      def song_list_by_genre(genres:, diffs:)
        genres.as_unique_array.product(diffs.as_unique_array).map do |genre, diff|
          assert_parameter :diff,  diff,  0..4, 10
          assert_parameter :genre, genre, 99, 101..106

          song_list :Genre, genre: genre, diff: diff
        end.inject({}, :update)
      end

      def song_list_by_title(characters:, diffs:)
        characters.as_unique_array.product(diffs.as_unique_array).map do |character, diff|
          assert_parameter :diff,      diff,      0..4
          assert_parameter :character, character, 0..15

          song_list :Word, word: character, diff: diff
        end.inject({}, :update)
      end

      def song_list_by_level(levels:)
        levels.as_unique_array.map do |level|
          assert_parameter :level, level, 1..6, 7..23

          song_list :Level, level: level
        end
      end

      def song_list_by_version(versions:, diffs:)
        versions.as_unique_array.product(diffs.as_unique_array).map do |version, diff|
          assert_parameter :diff,    diff,    0..4
          assert_parameter :version, version, 0..23

          song_list :Version, version: version, diff: diff
        end.inject({}, :update)
      end

      private
      def assert_parameter(key, value, *constraints)
        raw_value = value
        case value
        when MaimaiNet::Difficulty, MaimaiNet::Genre,
          MaimaiNet::NameGroup, MaimaiNet::LevelGroup,
          MaimaiNet::GameVersion
          raw_value = value.deluxe_web_id
        when Symbol
          raw_value = case key
                      when :diff;      MaimaiNet::Difficulty.new(value)
                      when :genre;     MaimaiNet::Genre.new(value)
                      when :character; MaimaiNet::NameGroup.new(value)
                      when :level;     MaimaiNet::LevelGroup.new(value)
                      when :version;   MaimaiNet::GameVersion.new(value)
                      else fail TypeError, "given Symbol, expected key is compatible constant class"
                      end
          raw_value = raw_value.deluxe_web_id
        end

        fail Error::ClientError, "#{key} type assertion fails." unless constraints.any? do |constraint|
          if constraint.respond_to?(:include?) then
            constraint.include?(raw_value)
          else
            constraint === raw_value
          end
        end
        nil
      end
    end

    class Base
      extend ConnectionProvider
    end

    class Connection
      include ConnectionSupportSongList
    end

    class << Connection
      def inherited(cls)
        cls.prepend ConnectionProtocol, ConnectionMaintenanceSafety
      end
    end

    class FaradayConnection < Connection
      # (see Connection#initialize)
      def initialize(client)
        super
        info = client.class.region_info

        @conn = Faraday.new(url: info[:base_host]) do |builder|
          builder.request  :url_encoded
          builder.response :follow_redirects
          builder.use      :cookie_jar, jar: client.cookies
        end
      end

      # insert logging middleware into the connector, replaces if necessary
      # @return [void]
      def log!
        replace_connector do |builder|
          builder.response :logger, nil, headers: false, bodies: false, log_level: :info
        end
      end

      # (see Connection#logout)
      def logout
        exclude_middlewares :follow_redirects do
          super
        end
      end

      # (see Connection#send_request)
      def send_request(method, url, data, **opts)
        body = Faraday::METHODS_WITH_BODY.include?(method) ? data : nil

        resp = @conn.run_request(
          method.to_s.downcase.to_sym, url,
          body, nil,
        ) do |req|
          req.params.update(data) if Faraday::METHODS_WITH_QUERY.include?(method) && Hash === data
        end

        process_response(
          url: resp.env.url,
          body: resp.body,
          request_options: opts,
        )
      end

      private
      def replace_connector(&block)
        orig = @conn
        if @conn.builder.instance_variable_get(:@app) then
          @conn = @conn.dup
          @conn.builder.instance_variable_set(:@app, nil) # reset app state to refresh the handlers
        end
        @conn.builder.build(&block)
        nil
      rescue
        @conn = orig
        nil
      end

      def exclude_middlewares(*middlewares)
        return if middlewares.empty?

        orig = @conn
        if @conn.builder.instance_variable_get(:@app) then
          @conn = @conn.dup
          @conn.builder.instance_variable_set(:@app, nil) # reset app state to refresh the handlers
        end
        middlewares.each do |middleware|
          if Symbol === middleware then
            [Faraday::Request, Faraday::Response, Faraday::Middleware].map do |mod|
              mod.registered_middleware[middleware]
            end.compact.first.tap do |result|
              fail ArgumentError, "#{middleware} is not registered" if result.nil?
              middleware = result
            end
          end
          @conn.builder.handlers.delete middleware
          fail Error::ClientError, "middleware #{middleware} is not removed yet from the stack" if @conn.builder.handlers.include? middleware
        end

        yield
      ensure
        @conn = orig
      end

      Base.register_connection :faraday, self
    end

    # @!parse class JapanRegion < Base; end
    # @!parse class AsiaRegion < Base; end
    Region.infos.each do |k, data|
      Class.new Base do
        @_properties = data.dup.freeze
      end.tap do |cls|
        const_set :"#{k.capitalize}Region", cls
        define_singleton_method k do cls end
      end
    end

    class << ConnectionProvider
      # make this module is exclusive to classes that already included them
      # and prevent further extension of it.

      private
      def append_features(cls); end
      def prepend_features(cls); end

      freeze
    end
  end
end
