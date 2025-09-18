module MaimaiNet
  module CoreExt
    module KernelAutoConstantInclusion
      MaimaiNet.constants.each do |k|
        cls = MaimaiNet.const_get(k)
        next unless Class === cls && cls < MaimaiNet::Constant

        define_method k do |key| cls.new(key) end
      end
    end
  end
end
