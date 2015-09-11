# Rufio

An I/O library that prefers to store bytes in RAM up to a certain size, but will
fall back to a [`Tempfile`][RubyDoc - Tempfile] once that size has been exceeded.

**NOTE:** If your [`Dir.tmpdir`][RubyDoc - Dir.tmpdir] is a
[tmpfs][Wikipedia - tmpfs] mount, you must initialize `Rufio::IO` instances with
an explicit `tmpdir` argument otherwise the `IO` instance will fall back from
RAM to RAM and limited benefit will be derived from this library.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "rufio"
```

And then execute:

```bash
$ bundle
```

Or install it yourself as:

```bash
$ gem install rufio
```

## Usage

Create a new `Rufio::IO` instance:

```ruby
  require "rufio/io"
  io = Rufio::IO.new
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`rake test` to run the tests. You can also run `bin/console` for an interactive
prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To
release a new version, update the version number in `version.rb`, and then run
`bundle exec rake release`, which will create a git tag for the version, push
git commits and tags, and push the `.gem` file to [rubygems.org][RubyGems].

## Contributing

Bug reports and pull requests are welcome on GitHub at [the project's
homepage][GitHub - Rufio].


## License

The gem is available as open source under the terms of the [MIT
License][MIT License].

[GitHub - Rufio]: https://github.com/tdg5/rufio "GitHub.com | tdg5/rufio"
[MIT License]: http://opensource.org/licenses/MIT "OpenSource.org - MIT License"
[RubyGems]: https://rubygems.org "RubyGems.org"
[RubyDoc - Tempfile]: http://ruby-doc.org/stdlib-2.2.2/libdoc/tempfile/rdoc/Tempfile.html "ruby-doc.org | Tempfile (Ruby 2.2.2)"
[RubyDoc - Dir.tmpdir]: http://ruby-doc.org/stdlib-2.2.2/libdoc/tmpdir/rdoc/Dir.html#method-c-tmpdir "ruby-doc.org | Dir.tmpdir"
[Wikipedia - tmpfs]: https://en.wikipedia.org/wiki/Tmpfs "Wikipedia.org | tmpfs"
