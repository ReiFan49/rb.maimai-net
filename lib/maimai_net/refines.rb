module MaimaiNet
  # includes AutoConstants into invokable class
  module IncludeAutoConstant
    refine Kernel do
      MaimaiNet.constants.each do |k|
        cls = MaimaiNet.const_get(k)
        next unless Class === cls && cls < MaimaiNet::Constant

        define_method k do |key| cls.new(key) end
      end
    end
  end

  # converts any object into a single-element array unless it's an array
  module ObjectAsArray
    refine Object do
      def as_array
        [self]
      end

      alias as_unique_array as_array
    end
    refine Array do
      def as_array
        self
      end

      def as_unique_array
        uniq
      end
    end
  end
end
