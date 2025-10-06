module MaimaiNet
  module CoreExt
    module AutoConstantInclusion
      MaimaiNet.constants.each do |k|
        cls = MaimaiNet.const_get(k)
        next unless Class === cls && cls < MaimaiNet::Constant

        define_method k do |key| cls.new(key) end
        private k
      end
    end
  end
end
