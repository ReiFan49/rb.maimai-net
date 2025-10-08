#!/usr/bin/env ruby
require 'bundler'

original_gemfile = File.read(Bundler.default_gemfile)

Bundler.locked_gems.specs.map do |lock_gem|
  gem_versions = Gem::Specification.find_all do |gem|
    gem.name === lock_gem.name
  end

  has_default_gem = gem_versions.any? &:default_gem?
  next unless has_default_gem

  default_gem = gem_versions.find &:default_gem?
  next if lock_gem.version === default_gem.version

  [lock_gem, default_gem]
end.compact.each do |lock_gem, gem|
  system('bundler', 'add', gem.name, '--skip-install', '--version', gem.version.to_s) ||
  system('bundler', 'add', gem.name, '--skip-install')
end.tap do |locked_gem_pair|
  next if locked_gem_pair.empty?

  # Revert Gemfile if needed
  # File.write(Bundler.default_gemfile, original_gemfile)
end
