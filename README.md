# MaimaiNet

Unofficial API for maimaiDXNET. This library simplifies several aspects that can be
loaded through maimaiDX website with couple of hassles.

This libary mostly being worked on as a core for my personal archiver.
Any feedback and suggestion regarding this library are welcomed.

## FAQ

- **Will you implement song blacklisting?**
  Until I can figure out how those hashed IDs work, no.
- **Does this support Japan region?**
  Untested for now, I need to prepare the whole flow for both Japan and Asia version.
- **Is there any online non-Japan and Asia region?**
  Check it by your own, at least the SilentBlue web. If the US region is combined with Asia, there you go, use the Asia endpoint in the end.
- **Any plan to support Ruby 2.6?** I wish.
- **Any plan to support Ruby 3.0+?** I can attempt to backport them, the same consideration as if I do Ruby 2.6 support instead.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'maimai_net'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install maimainet

## Usage

```ruby
require 'maimai_net'
client = MaimaiNet::Client.asia.new(username, password)
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).
