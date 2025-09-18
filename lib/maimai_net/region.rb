module MaimaiNet
  # constant group that defines maimai server region
  #
  # @note any of modules defined in here can't be included nor modified any further.
  module Region
    module Base
      def self.append_features(cls)
        super
        cls.const_set :WEBSITE_BASE, cls.const_get(:BASE_HOST) + '/maimai-mobile'
      end
    end

    # maimai DX Japan Server constants
    module Japan
      BASE_HOST = URI('https://maimaidx.jp')
      include Base
      LOGIN_PAGE_PROC = ->(site){
        site.host == WEBSITE_BASE.host && (
          site.path == WEBSITE_BASE.path ||
          site.path == WEBSITE_BASE.path + '/'
        )
      }
    end

    # maimai DX Asia Server constants
    module Asia
      BASE_HOST = URI('https://maimaidx-eng.com')
      include Base
      LOGIN_PAGE_PROC = ->(site){
        site.host.end_with?('.am-all.net') &&
        site.path.split('/').first(3).join('/') == '/common_auth/login'
      }
      LOGIN_ERROR_PROC = ->(site, body) {
        LOGIN_PAGE_PROC.call(site) &&
        %r{<([\S]+)(?:\s+[^>]+)?>Error</\1>}i.match?(body)
      }
    end

    class << self
      include ModuleExt::MethodCache

      # @return [Array<Symbol>] list of available regions
      cache_method :list do
        regions.keys.freeze
      end

      # @return [Hash{Symbol => Module}] mapping of region key and its respective module
      cache_method :regions do
        constants.map do |k|
          mod = const_get(k)
          [k.downcase, mod]
        end.sort_by(&:object_id).select do |name, mod|
          mod.is_a?(Module) && mod < Base
        end.to_h.freeze
      end

      # @return [Hash{Symbol => Hash{Symbol => Object}}] mapping of region properties in Hash-friendly format.
      cache_method :infos do
        regions.map do |k, mod|
          d = mod.constants.map do |ck| [ck.downcase, mod.const_get(ck)] end.to_h
          [k, d]
        end.to_h.freeze
      end

      # guess server region based on provided URL.
      #
      # Conditions for a url considered as the server region are either:
      # - uri is either exact component or sublevel of provided server's website uri.
      # - uri should match server's internal login page.
      #
      # @param uri [String, URI] URL to check it's region
      # @return [Symbol] region name for given url.
      # @return [nil]    none of the region matches.
      cache_method :guess # do |uri|
      def guess(uri)
        return method(__method__).call(URI(uri)) unless URI::Generic === uri

        infos.select do |k, data|
          (
            %i(scheme userinfo host port).all? do |k|
              data[:website_base].public_send(k) == uri.public_send(k)
            end && (
              uri.path == data[:website_base].path ||
              uri.path.start_with?(data[:website_base].path + '/')
            )
          ) || (
            data[:login_page_proc].call(uri)
          )
        end.keys.shift
      end

      private :regions
    end
  ensure
    # Freeze all modules and prevent from inclusion
    mods = constants.map do |k| const_get(k) end
    mods << self

    private_constant :Base

    mods.each do |mod|
      %i(append_features prepend_features).each do |meth|
        mod.define_singleton_method meth do |cls| end
      end
      mod.freeze
    end
  end
end
