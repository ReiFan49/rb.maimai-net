require 'fiddle'

module MaimaiNet
  # collection of modules with extended functionality
  #
  # @note some of these modules may be moved out into a separate gem in a later date.
  module CoreExt
    # enables capability of having class_method block definition for a module.
    # @note it's not valid to use this outside this file.
    module HaveClassMethods
      # defines an internal module to be inherited into
      # calling class's eugenclass.
      # @return [void]
      def class_method(&block)
        ref = self
        @_class_module ||= Module.new
        @_class_module.instance_eval <<~EOF
          def to_s
            "#{ref}::ClassMethod"
          end
          alias inspect to_s
        EOF
        @_class_module.class_exec(&block)
      end

      # defines a hook to automatically extend target class
      # with internal module from #class_method
      # @param cls [Class] calling class
      # @return [void]
      def included(cls)
        super

        base = self
        cls.instance_exec do
          next unless Class === cls
          next unless base.instance_variable_defined?(:@_class_module)
          next unless Module === base.instance_variable_get(:@_class_module)
          ext_class = base.instance_variable_get(:@_class_module)
          # the use of singleton_class.include and extend are the same.
          extend ext_class
          # singleton_class.send(:include, ext_class)
        end
      end
    end

    # extends inspect function into customizable inspect output
    module ExtendedInspect
      extend HaveClassMethods

      # @return [String] simplified human-readable output
      def inspect
        head = '%s:%0#*x' % [
          self.class.name,
          0.size.succ << 1,
          Fiddle.dlwrap(self),
        ]

        vars = []
        all_true             = !self.class.instance_variable_defined?(:@_inspect_permit)
        if all_true then
          permit_variables   = []
          permit_expressions = []
          exclude_variables  = []
        else
          all_true          |= !self.class.instance_variable_get(:@_inspect_permit)

          permit_variables   = self.class.instance_variable_get(:@_inspect_permit_variables)
          permit_expressions = self.class.instance_variable_get(:@_inspect_permit_expressions)
          exclude_variables  = self.class.instance_variable_get(:@_inspect_permit_variable_bans)

          all_true          |= [
            permit_variables,
            exclude_variables,
            permit_expressions,
          ].all?(&:empty?)
        end

        self.instance_variables.each do |k|
          name = k.to_s[1..-1].to_sym
          value = self.instance_variable_get(k)

          next if exclude_variables.include? name

          is_permit = all_true

          unless is_permit
            is_permit |= permit_variables.include?(name)
            is_permit |= permit_expressions.any? do |expr| !!expr.call(value) end
          end

          vars << sprintf(
            '@%s=%s',
            name,
            is_permit ? value.inspect : value.class.name,
          )
        end

        '#<%s>' % [
          [head, *vars].join(' '),
        ]
      end

      class_method do
        # inherits inspect permit from superclass
        def inherited(cls)
          super

          %i(
            inspect_permit
            inspect_permit_variables
            inspect_permit_variable_bans
            inspect_permit_expressions
          ).each do |k|
            name = :"@_#{k}"
            source = instance_variable_get(name)
            value = source.dup rescue source

            cls.instance_variable_set(name, value)
          end
        end

        private

        # @return [void]
        def inspect_permit_reset!
          @_inspect_permit = false
          @_inspect_permit_variables = []
          @_inspect_permit_variable_bans = []
          @_inspect_permit_expressions = []
        end

        # @param names [Array<String, Symbol>] list of variable name to permit by default
        # @return [void]
        def inspect_permit_variables(*names)
          fail ArgumentError, 'empty list given' if names.empty?
          fail ArgumentError, 'non-String given' if names.any? do |name| !(String === name || Symbol === name) end

          @_inspect_permit ||= true
          @_inspect_permit_variables.concat names.map(&:to_s).map(&:to_sym)
          nil
        end

        # @param names [Array<String, Symbol>] list of variable name to exclude from inspection
        # @return [void]
        def inspect_permit_variable_exclude(*names)
          fail ArgumentError, 'empty list given' if names.empty?
          fail ArgumentError, 'non-String given' if names.any? do |name| !(String === name || Symbol === name) end

          @_inspect_permit ||= true
          @_inspect_permit_variable_bans.concat names.map(&:to_s).map(&:to_sym)
          nil
        end

        # @param block [#call] a predicate method or block that accepts
        #   single argument of instance variable value to permit for.
        # @return [void]
        def inspect_permit_expression(&block)
          fail ArgumentError, 'no block given' unless block_given?

          @_inspect_permit ||= true
          @_inspect_permit_expressions.push block
          nil
        end
      end

      # initializes inspect permit variables upon inclusion
      # @note will not apply to modules.
      # @return [void]
      def self.included(cls)
        super

        cls.instance_exec do
          inspect_permit_reset!
        end if Class === cls
      end
    end

    module AddInternalMutex
      extend HaveClassMethods

      class_method do
        private
        def lock(key, meth, &block)
          @_method_mutex ||= {}
          @_method_mutex[key] ||= {}
          can_lock = !@_method_mutex[key].fetch(meth, nil)&.locked?
          # $stderr.puts "#{key}/#{meth} lock #{can_lock}"
          return unless can_lock

          mutex = @_method_mutex[key][meth] = Mutex.new
          mutex.lock
          yield
        ensure
          if can_lock then
            mutex.unlock if mutex.locked?
            @_method_mutex[key].delete(meth) if can_lock
          end
        end
      end
    end

    # automatically private any initialize-based methods
    module AutoInitialize
      extend HaveClassMethods

      class_method do
        # automatically private any initialize-based methods
        # @return [void]
        def method_added(meth)
          private meth if /^initialize_/.match? meth
          super
        end
      end
    end

    # allows registering methods into cacheable results.
    module MethodCache
      extend HaveClassMethods

      # Hooks method that specified through cache_method with internal cache wrapper.
      # @see #cache_method
      def singleton_method_added(meth)
        singleton_class.class_exec do
          is_locked = false
          mutex = @_method_mutex.to_h.dig(:cache_method, meth)
          is_locked = mutex.locked? if mutex && mutex.locked?

          if @_cache_methods&.include?(meth) && !is_locked then
            alias_method :"raw_#{meth}", meth
            _cache_method(meth)
          end
        end

        super
      end

      class_method do
        # only copies methods to hook definition
        # @return [void]
        def inherited(cls)
          super

          %i(
            cache_methods
            cache_results
          ).each do |k|
            name = :"@_#{k}"
            source = instance_variable_get(name)
            value = source.dup rescue source

            cls.instance_variable_set(name, value)
          end

          cls.instance_variable_get(:@_cache_results)&.tap do |result|
            source = instance_variable_get(:@_cache_results)
            result.clear
            result.default_proc = source.default_proc
          end
        end

        # Hooks method that specified through cache_method with internal cache wrapper.
        # @see #cache_method
        def method_added(meth)
          is_locked = false
          mutex = @_method_mutex.to_h.dig(:cache_method, meth)
          is_locked = mutex.locked? if mutex && mutex.locked?

          if @_cache_methods&.include?(meth) && !is_locked then
            alias_method :"raw_#{meth}", meth
            _cache_method(meth)
          end

          super
        end

        private

        # This method works in a few ways.
        # If a block is given, this acts like define_method but automatically hooked on-the-fly.
        # Else if the method is previously defined, it will wrap the method into cached method.
        # Otherwise, just add the method to the internal list to hook upon definition.
        #
        # @note does not support methods with any arity yet.
        # @param meth [String, Symbol] method name to cache for
        # @return [String, Symbol] meth parameter returned.
        def cache_method(meth, &block)
          if block_given? then
            define_method :"raw_#{meth}", &block
            _cache_method(meth)
          else
            @_cache_methods ||= []
            @_cache_methods << meth

            if instance_methods.include? meth then
              if private_instance_methods.include? :"raw_#{meth}" then
                warn "%s: ignoring private method aliasing for '#{meth}'." % [caller_locations(1, 1).first] if $VERBOSE
              else
                alias_method :"raw_#{meth}", meth
              end
              _cache_method(meth)
            else
              # fail NotImplementedError, "cannot lazy-hook '#{meth}' method for singleton class, please define using 'cache_method #{meth.inspect} do ... end' block instead." if singleton_class?
            end
          end

          meth
        end

        # @!api private
        # decorator to redefine method to support cached result.
        # @param meth [String, Symbol] method name to redefine
        # @return [void]
        # @see #cache_method
        def _cache_method(meth)
          first, *stack = caller_locations(0)
          stack_fit = ->(count, *labels){
            last = stack[count.pred]
            first.absolute_path == last.absolute_path &&
              labels.map(&:to_s).include?(last.label)
          }

          fail 'cannot call this method from outside' unless
            stack_fit.call(1, :cache_method, :method_added) ||
            stack_fit.call(3, :singleton_method_added)

          private :"raw_#{meth}"
          cache = @_cache_results
          invoke = ->(meth, *args, **kwargs, &block) {
            kwargs.empty? ?
              meth.call(*args, &block) :
              meth.call(*args, **kwargs, &block)
          }
          map_parameters = ->(meth, *args, **kwargs, &block) {
            parameters  = meth.parameters.map(&:first)
            positionals = {front: [], rest: args, back: []}
            pos_rest_at = parameters.index(:rest)
            if pos_rest_at.nil? then
              positionals[:front] = args
              positionals[:rest]  = []
            else
              positionals[:front] = args.slice! (...pos_rest_at)
              positionals[:back]  = args.slice! ((pos_rest_at + 1)..)
            end

            keyword_names = meth.parameters.select do |t, k| %i(keyreq key).include? k end
            keywords, options = keyword_names.select do |t, k| %i(keyreq key keyrest).include? k end
                                  .partition do |t, k| %i(keyreq key).include?(k) end
                                  .map do |li|
                                    kwargs.values_at(*li.map(&:last))
                                  end

            have_block = parameters.include? :block
            raw_parameters = [
              *positionals[:front],
              positionals[:rest],
              *positionals[:back],

              keywords, options,
            ]
            raw_parameters << block if have_block

            raw_parameters
          }

          use_param_hash = true

          lock :cache_method, meth do
            define_method meth do |*args, **kwargs, &block|
              m = method(:"raw_#{meth}")
              if use_param_hash and not(args.empty? and kwargs.empty?) then
                param_hash = map_parameters.call(m, *args, **kwargs, &block).hash
                return cache[meth][__id__][param_hash] if cache.key?(meth) && cache[meth].key?(__id__) && cache[meth][__id__].key?(param_hash)
                cache[meth][__id__] = {} unless cache[meth].key? __id__
                cache[meth][__id__][param_hash] = invoke.call(m, *args, **kwargs, &block)
              else
                return cache[meth][__id__] if cache.key?(meth) && cache[meth].key?(__id__)
                cache[meth][__id__] = invoke.call(m, *args, **kwargs, &block)
              end
            end
          end
        end
      end

      # initializes internal data for method caching
      # @return [void]
      def self.included(cls)
        cls.class_exec do
          include AddInternalMutex
        end

        super

        cls.class_exec do
          if singleton_class? then
            # define_method :singleton_method_added, method(:method_added).unbind
            singleton_class.undef_method :method_added
          else
            undef_method :singleton_method_added
          end
        end

        cls.instance_exec do
          proc_key_to_id = ->(h, k){
            case k
            when Integer
              h[k]
            when Float, NilClass, TrueClass, FalseClass
              fail KeyError, "invalid key"
            else
              h[k.object_id]
            end
          }

          @_cache_methods ||= []
          @_cache_results ||= Hash.new do |h, k|
            next h[k.to_sym] if h.key?(k.to_sym)
            h[k.to_sym] = Hash.new &proc_key_to_id
          end
        end
      end
    end

    %i(ExtendedInspect AutoInitialize).tap do |keys|
      const_list = keys.map do |k| const_get k end
      keys.each do |k| remove_const k end

      [
        %i(append_features include),
        %i(prepend_features prepend),
      ].each do |(source_meth, internal_meth)|
        define_singleton_method source_meth do |cls|
          cls.__send__ internal_meth, *const_list
        end
      end
    end

    remove_const :HaveClassMethods
  end
end
