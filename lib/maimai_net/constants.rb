module MaimaiNet
  module Constants
    class AchievementFlag
      COMBO = %i(fc ap)
      SYNC  = %i(sync fs fsd)
      PLUS  = %i(fc ap fs fsd)

      sym_iter = ->(&block){
        (COMBO + SYNC).lazy.flat_map do |bk|
          [bk, *(PLUS.include?(bk) ? [:"#{bk}+"] : [])]
        end.map do |k|
          is_plus = k.end_with?('+')
          plusless = is_plus ? k[0...-1] : k.to_s
          [k, plusless, is_plus]
        end.map(&block)
      }

      KEYS = sym_iter.call do |k, bk, plus| k.upcase end
      RECORD = sym_iter.call do |k, bk, plus|
        [k.upcase, -(plus ? "#{bk}p" : bk)]
      end.to_h
      RESULT = sym_iter.call do |k, bk, plus|
        [k.upcase, -(plus ? "#{bk}plus" : bk)]
      end.to_h

      include CoreExt

      def initialize(key)
        @key = key

        @record_key = RECORD[key]
        @result_key = RESULT[key]

        freeze
      end

      attr_reader :key
      attr_reader :record_key, :result_key

      alias id key
      alias to_sym key

      VALID_ATTRIBUTES = instance_methods(false)
        .map(&method(:instance_method))
        .map(&:original_name)
        .sort.uniq

      undef_method :clone, :dup

      constants.map(&method(:const_get))
        .map(&:freeze)

      class << self
        def new(key)
          @map  ||= {}
          @keys ||= {}

          case key
          when Pathname; key = key.to_s
          when Integer
            key = @map.values.find do |obj| obj.id == key end&.key or key if VALID_ATTRIBUTES.include?(:id)
          when Hash
            if !@map.empty? && key.size == 1 then
              data_key, data_value = key.first
              if VALID_ATTRIBUTES.include? data_key.to_sym then
                key = @map.values.find do |obj| obj.public_send(data_key) == data_value end&.key or key
              end
            end
          end

          if key.respond_to?(:to_sym) then
            key = key.upcase.to_sym
          end
          fail TypeError, "expected Symbol, given #{key.class}" unless Symbol === key

          if @keys.key?(key) then
            obj = @map[@keys[key]]
          else
            key = key.upcase
            obj = super
            @map[obj.object_id] = obj
            names = [key]
            names << obj.abbrev if instance_methods.include?(:abbrev)
            [key].each do |k|
              @keys.store k, obj.object_id
            end
          end

          obj
        end
      end

      RECORD.keys.each &method(:new)
    end

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
      }

      DELUXE = {
        all:      0,
        basic:    1,
        advanced: 2,
        expert:   3,
        master:   4,
        remaster: 5,
        utage:    10,
      }

      DELUXE_WEBSITE = {
        all:      99,
        basic:    0,
        advanced: 1,
        expert:   2,
        master:   3,
        remaster: 4,
        utage:    10,
      }

      LIBRARY = {
        all:      0,
        easy:     1,
        basic:    2,
        advanced: 3,
        expert:   4,
        master:   5,
        remaster: 6,
        utage:    10,
      }

      SHORTS = {
        easy:     :EM,
        basic:    :BS,
        advanced: :AD,
        expert:   :EX,
        master:   :MS,
        remaster: :RMS,
      }

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
        .sort.uniq

      undef_method :clone, :dup

      constants.map(&method(:const_get))
        .map(&:freeze)

      class << self
        def new(key)
          @map  ||= {}
          @keys ||= {}

          case key
          when Pathname; key = key.to_s
          when Integer
            key = @map.values.find do |obj| obj.id == key end&.key or key
          when Hash
            if !@map.empty? && key.size == 1 then
              data_key, data_value = key.first
              if VALID_ATTRIBUTES.include? data_key.to_sym then
                key = @map.values.find do |obj| obj.public_send(data_key) == data_value end&.key or key
              end
            end
          end

          if key.respond_to?(:to_sym) then
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
end
