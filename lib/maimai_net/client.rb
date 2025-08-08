require 'faraday'
require 'faraday/follow_redirects'
require 'nokogiri'

require 'maimai_net/page'
require 'maimai_net/faraday_ext/cookie_jar'

module MaimaiNet
  module Client
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

      # access finale archive page
      # @return [Page::FinaleArchive] player's archived maimai finale statistics
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
      # @raise [Error::LoginError]   if error code describes an invalid login
      # @raise [Error::GeneralError]
      def on_error(body)
        page = Nokogiri::HTML.parse(body)
        error_elm = page.at_css('.container_red > div')
        error_note = error_elm.text
        error_code = error_note.match(/\d+/).to_s.to_i

        case error_code
        when 100101
          fail Error::LoginError, error_code
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
      # @return [Model::Base] returns page data based from provided response_page field
      # @return [void]
      def send_request(method, url, data, **opts)
        fail NotImplementedError if @conn.nil?
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

    class Base
      extend ConnectionProvider
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

      # (see Connection#send_request)
      def send_request(method, url, data, **opts)
        info = @client.class.region_info
        body = Faraday::METHODS_WITH_BODY.include?(method) ? data : nil

        resp = @conn.run_request(
          method.to_s.downcase.to_sym, url,
          body, nil,
        ) do |req|
          req.params.update(data) if Faraday::METHODS_WITH_QUERY.include?(method) && Hash === data
        end

        if info.key?(:login_error_proc) && info[:login_error_proc].call(resp.env.url, resp.body) then
          return on_login_error
        elsif resp.env.url == URI.join(info[:website_base], info[:website_base].path + '/', 'error/') then
          return on_error(resp.body)
        elsif info[:login_page_proc].call(resp.env.url) then
          return on_login_request(resp.env.url, resp.body, **opts)
        end
        # end

        if Class === opts[:response_page] && opts[:response_page] < Page::Base then
          return opts[:response_page].parse(resp.body).data
        end

        nil
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
