module MaimaiNet
  module Constants
    class Difficulty
      ORIGINAL = {
        all:      0,
        easy:     1,
        basic:    2,
        advanced: 3,
        expert:   4,
        master:   5,
        remaster: 6,
        utage:    10,
      }.freeze

      DELUXE = {
        all:      0,
        basic:    1,
        advanced: 2,
        expert:   3,
        master:   4,
        remaster: 5,
        utage:    10,
      }.freeze

      DELUXE_WEBSITE = {
        all:      99,
        basic:    0,
        advanced: 1,
        expert:   2,
        master:   3,
        remaster: 4,
        utage:    10,
      }.freeze

      LIBRARY = {
        all:      0,
        easy:     1,
        basic:    2,
        advanced: 3,
        expert:   4,
        master:   5,
        remaster: 6,
        utage:    10,
      }.freeze

      SHORTS = {
        easy:     :EM,
        basic:    :BS,
        advanced: :AD,
        expert:   :EX,
        master:   :MS,
        remaster: :RMS,
      }.freeze

      include CoreExt

      def initialize(key)
        @key = key

        @id            = LIBRARY[key]
        @original_id   = ORIGINAL[key]
        @deluxe_id     = DELUXE[key]
        @deluxe_web_id = DELUXE_WEBSITE[key]

        @abbrev        = SHORTS.fetch(key, key.upcase)

        freeze
      end

      attr_reader :key, :abbrev
      attr_reader :id, :original_id, :deluxe_id, :deluxe_web_id

      alias long   key
      alias to_i   id
      alias to_sym key

      VALID_ATTRIBUTES = instance_methods(false)
        .map(&method(:instance_method))
        .map(&:original_name)
        .sort.uniq.freeze

      undef_method :clone, :dup

      class << self
        def new(key)
          @map  ||= {}
          @keys ||= {}

          if !@map.empty? && Hash === key && key.size == 1 then
            data_key, data_value = key.first
            if VALID_ATTRIBUTES.include? data_key.to_sym then
              key = @map.values.find do |obj| obj.public_send(data_key) == data_value end&.key or key
            end
          elsif key.respond_to?(:to_sym) then
            key = key.to_sym
          end
          fail TypeError, "expected Symbol, given #{key.class}" unless Symbol === key

          if @keys.key?(key) then
            obj = @map[@keys[key]]
          else
            key = key.downcase
            obj = super
            @map[obj.object_id] = obj
            [key, obj.abbrev].each do |k|
              @keys.store k, obj.object_id
            end
          end

          obj
        end
      end

      LIBRARY.keys.each &method(:new)
    end
  end

  include Constants
  private_constant :Constants

  def self.Difficulty(key); Difficulty.new(key); end
end
