module MaimaiNet
  module UserOption
    Option = Struct.new(:name, :choices, :selected) do
      def select(value)
        new_selected = choices.find do |choice|
          choice.match?(value)
        end

        fail ArgumentError, "invalid value selected" if new_selected.nil?
        self.selected = new_selected
      end

      alias pick select

      def selected_id
        self.selected.value
      end

      def to_a
        [self.name, self.selected_id]
      end

      def to_h
        Hash[*to_a]
      end

      alias to_ary  to_a
      alias to_hash to_h
    end

    Choice = Struct.new(:group, :value, :description) do
      @symbol_alias_hooks = {
        full: [],
        partial: [],
      }.freeze

      def initialize(*args)
        super

        @alias_symbol = symbol_alias_of
        @alias_value  = value_alias_of
      end

      attr_reader :alias_symbol, :alias_value

      def matches
        description_value = !@alias_value.nil? ? description : nil
        [self.value, description_value, @alias_symbol, @alias_value].compact.uniq
      end

      def match?(value)
        matches.include?(value)
      end

      private
      def symbol_alias_of
        return if /^[-]?(?:0|[1-9]+[0-9]*)(?:[.][0-9]+)?$/.match?(description)

        hooks = self.class.instance_variable_get(:@symbol_alias_hooks)
        fully_replaced = false
        value = description.dup
        group_name = (String === self.group ? self.group : self.group.name).dup.freeze
        value.dup.yield_self do |temp_value|
          hooks[:full].each do |hook|
            hook.call(group_name, temp_value)
            fully_replaced |= temp_value != value
            break if fully_replaced
          end

          value.replace temp_value if fully_replaced
        end

        value.dup.yield_self do |temp_value|
          hooks[:partial].each do |hook|
            hook.call(group_name, temp_value)
          end

          value.replace temp_value if temp_value != value
        end unless fully_replaced

        if /^[\x20-\x7f]+$/.match?(value) then
          value.downcase.scan(/[a-z0-9]+/).join('_').to_sym
        end
      end

      def value_alias_of
        case description
        when /^[-]?(?:0|[1-9]+[0-9]*)$/; Integer($&)
        when /^[-]?(?:0|[1-9]+[0-9]*)(?:[.][0-9]+)?$/; Float($&)
        end
      end

      def self.add_symbol_hook(key, func)
        @symbol_alias_hooks.fetch(key)
          .push(func)

        self
      end

      add_symbol_hook :partial, ->(group, value) {
        value.gsub! /['×・]/, ''
      }
      add_symbol_hook :partial, ->(group, value) {
        value.gsub! /[＆～]/ do |sym| ((sym.ord & ~0xff00) + 0x20).chr end
      }
      add_symbol_hook :partial, ->(group, value) {
        value.gsub! /[(]([a-z]+)[)]/i, ' \1 '
      }
      add_symbol_hook :partial, ->(group, value) {
        value.gsub! /[(](?:[a-z]*[+\-♦])[)]/i, {
          '(+)' => ' increase ',
          '(-)' => ' decrease ',
          '(MAX-)' => ' decrease ',
          '(♦)' => ' grade ',
        }
      }
      add_symbol_hook :partial, ->(group, value) {
        value.gsub! /(\d+)-(\w+)/ do sprintf('-%s%s', $1, $2) end
      }
      add_symbol_hook :partial, ->(group, value) {
        value.gsub! /[\u2460-\u2473]/ do |sym| " #{(sym.ord - 0x2460) + 1}" end
      }
      add_symbol_hook :partial, ->(group, value) {
        value.gsub! 'でらっくスコア', 'DX Score '
      }

      conversion = {
        '⇔' => 'Mirror',
        '⇅' => 'Flip',
        '↻' => 'Rotate',
      }
      translation = {
        'デフォルト' => 'Default',
        'シンプル' => 'Simple',
        'クラシック' => 'Classic',
        'でらっくす' => 'Deluxe',
        'スプラッシュ' => 'Splash',
      }
      {}.merge(conversion, translation).tap do |convert_map|
        pattern = Regexp.union(convert_map.keys)
        add_symbol_hook :full, ->(group, value) {
          value.gsub! pattern, convert_map
        }
      end
    end
  end
end
