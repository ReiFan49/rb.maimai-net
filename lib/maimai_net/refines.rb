module MaimaiNet
  module IncludeDifficulty
    refine Kernel do
      def Difficulty(key); MaimaiNet::Difficulty.new(key) end
    end
  end
end
