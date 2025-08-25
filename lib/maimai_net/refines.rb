module MaimaiNet
  # includes Difficulty into invokable class
  module IncludeDifficulty
    refine Kernel do
      def Difficulty(key); MaimaiNet::Difficulty.new(key) end
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
