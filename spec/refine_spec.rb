# This is a mandatory refinement test as this problem
# were found during development of the Rails server.

target = BasicObject

RSpec.describe "#{target} refinement" do
  def open_and_expect(intro)
    IO.popen('ruby', 'w+', err: :out) do |pio|
      pio.write <<~EOT
        require 'maimai_net'
      EOT

      pio.puts intro unless intro.to_s.empty?

      pio.write <<~EOT
        class << Object.new
          using MaimaiNet::IncludeAutoConstant
          Difficulty(1)
        end
      EOT

      pio.close_write
      pio.read
    end

    expect($?).to be_success
  end

  it "when no modification to #{target}" do
    open_and_expect(nil)
  end

  it "when #{target} have inclusion" do
    open_and_expect("#{target}.include Module.new")
  end

  it "when #{target} have upfront inclusion" do
    open_and_expect("#{target}.prepend Module.new")
  end
end
