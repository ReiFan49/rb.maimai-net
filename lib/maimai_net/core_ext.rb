module MaimaiNet
  module CoreExt
    # contains every {Constants AutoConstant} classes turned into a function.
    # used for include or prepend in a scope.
    #
    # also used in `refine` {IncludeAutoConstant}.
    module AutoConstantInclusion
      MaimaiNet.constants.each do |k|
        cls = MaimaiNet.const_get(k)
        next unless Class === cls && cls < MaimaiNet::Constant

        define_method k do |key| cls.new(key) end
        private k
      end
    end

    # adds JSON conversion support through `#to_h` conversion.
    module JSONSupport
      def as_json(options = nil)
        to_h.transform_values do |val|
          val.respond_to?(:as_json) ?
            val.as_json(options) : val
        end
      end

      def to_json(options = nil)
        as_json.to_json(options)
      end
    end
  end
end
