require 'faraday'
require 'http/cookie'

module MaimaiNet
  module FaradayExt
    # Slight modification from faraday-cookie_jar to follow domain redirects on response.
    class CookieJar < Faraday::Middleware
      def initialize(app, options = {})
        super(app)
        @jar = options[:jar] || HTTP::CookieJar.new
      end

      def call(env)
        cookies = @jar.cookies(env[:url])
        unless cookies.empty?
          cookie_header = {}
          # assign them to dummy cookie to make it compatible
          HTTP::Cookie.parse(env[:request_headers]["Cookie"], env[:url]).each do |cookie|
            cookie_header[cookie.name] = cookie.cookie_value
          end if env[:request_headers]['Cookie']

          cookies.each do |cookie| cookie_header[cookie.name] = cookie.cookie_value end
          env[:request_headers]["Cookie"] = HTTP::Cookie.cookie_value(cookie_header.values)
        end

        @app.call(env).on_complete do |res|
          if set_cookie = res[:response_headers]["Set-Cookie"]
            @jar.parse(set_cookie, res[:url])
          end if res[:response_headers]
        end
      end
    end

    Faraday::Middleware.tap do |m|
      m.register_middleware cookie_jar: CookieJar
    end if Faraday::Middleware.respond_to? :register_middleware
  end
end
