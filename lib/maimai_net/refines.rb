module MaimaiNet
  # injects {CoreExt::AutoConstantInclusion} into {Kernel} and {BasicObject}.
  # @note A bug noticed from v0.0.1 where refining Kernel only
  #   is not reliable due to prepending on Kernel causes
  #   all refines on Kernel are invalidated. A band-aid solution
  #   for this is also injecting BasicObject with the same refine.
  module IncludeAutoConstant
    refine Kernel do
      include CoreExt::AutoConstantInclusion
    end
    refine BasicObject do
      include CoreExt::AutoConstantInclusion
    end
  end

  # grants any object an ability to convert itself into a single-element array.
  # unless it's an array already.
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
