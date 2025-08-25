module MaimaiNet
  module Constants
    module AutoConstant
      def self.extend_object(cls)
        super
        return unless Module === cls

        cls.class_exec do
          const_set :VALID_ATTRIBUTES, instance_methods(false)
            .map(&method(:instance_method))
            .map(&:original_name)
            .sort.uniq

          alias_method :clone, :itself
          alias_method :dup,   :itself
          undef_method :initialize_copy

          constants.map(&method(:const_get))
            .map(&:freeze)
        end
      end

      def define_new(key_enforce: nil, extra_lookup_keys: [])
        builder = []
        builder << <<~EOT
          @map  ||= {}
          @keys ||= {}
        EOT

        key_conditions = {}
        key_conditions[Pathname] = 'key = key.to_s'
        key_conditions[Hash] = <<~EOS
          if !@map.empty? && key.size == 1 then
            dk, dv = key.first
            key = @map.values.find do |obj| obj.public_send(dk) == dv end&.key or key if const_get(:VALID_ATTRIBUTES).include? dk.to_sym
          end
        EOS

        key_conditions[Integer] = <<-EOS if const_get(:VALID_ATTRIBUTES).include?(:id)
          key = @map.values.find do |obj| obj.id == key end&.key or key
        EOS

        builder << "case key\n%s\nend" % [key_conditions.map do |k, v| "when #{k}\n  #{v}" end.join($/)]

        if Symbol === key_enforce then
          builder << <<~EOT
            key = key.#{key_enforce}.to_sym if key.respond_to?(:to_sym)
            fail TypeError, "expected Symbol, given %s" % [key.class] unless Symbol === key
          EOT
        else
          builder << <<~'EOT'
            fail TypeError, "expected Symbol, given %s" % [key.class] unless Symbol === key
          EOT
        end

        extra_lookup_builder = extra_lookup_keys.map do |k|
          "names << obj.#{k}"
        end

        key_enforce_builder = ''
        key_enforce_builder = "key = key.#{key_enforce}" if Symbol === key_enforce

        builder << <<~EOT
          if @keys.key?(key) then
            obj = @map[@keys[key]]
          else
            #{key_enforce_builder}
            obj = super
            @map[obj.object_id] = obj
            names = [key]
            #{extra_lookup_builder * $/}
            names.each do |k|
              @keys.store k, obj.object_id
            end
          end
        EOT

        builder << 'obj'

        stack = caller_locations(1).first
        instance_eval "def new(key)\n%s\nend" % [builder.join($/)],
          stack.path, stack.lineno
      end

      def populate_entries(constant_or_list)
        list = nil

        case constant_or_list
        when Symbol
          list = const_get(constant_or_list)
        else
          list = constant_or_list
        end

        case list
        when Hash
          list = list.keys
        when Enumerable
          list = list.to_a
        else
          if Symbol === constant_or_list then
            fail ArgumentError, "expected constant #{constant_or_list} is an enumerable, given #{list.class}"
          else
            fail TypeError, "expected a constant name or an enumerable, given #{constant_or_list.class}"
          end
        end

        singleton_class.undef_method __method__ rescue 0
        list.each &method(:new)
      end
    end

    private_constant :AutoConstant

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

      extend AutoConstant
      define_new key_enforce: :upcase
      populate_entries :RECORD
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

      extend AutoConstant
      define_new key_enforce: :downcase, extra_lookup_keys: %i(abbrev)
      populate_entries :LIBRARY
    end
  end

  include Constants
  private_constant :Constants
end
