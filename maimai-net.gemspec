require_relative 'lib/maimai_net/version'

Gem::Specification.new do |spec|
  spec.name          = "maimai_net"
  spec.version       = MaimaiNet::VERSION
  spec.authors       = [
    %(Rei Hakurei),
  ]
  spec.email         = %w(contact@bloom-juery.net)

  spec.summary       = %q(Parses maimai-net into readable data.)
  spec.homepage      = 'https://github.com/ReiFan49/rb.maimai-net'
  spec.required_ruby_version = Gem::Requirement.new(">= 2.7.0")

  # spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  begin
    spec.files       = Dir.chdir(File.expand_path('..', __FILE__)) do
      `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
    end
  rescue Errno::ENOENT
    spec.files       = Dir.glob('lib/**/*.rb', base: File.expand_path('..', __FILE__))
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'nokogiri', '~> 1.13'
  spec.add_runtime_dependency 'faraday',  '~> 2.0'
  spec.add_runtime_dependency 'faraday-follow_redirects'

  spec.add_runtime_dependency 'http-cookie', '~> 1.0.0'
end
