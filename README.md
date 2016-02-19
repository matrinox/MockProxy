# MockProxy

A proxy that can be used to stub method chains and more!

## Description

Remember when RSpec had `stub_chain`? They removed it for good reasons but sometimes you just need it.
Well, here it is, a proxy object. It doesn't actually mock anything for you (the name is just catchy) so you need to do that.
But that actually comes with a lot of benefits:

1. It's compatable with any testing framework
2. You can use it for purposes other than testing, e.g. prototyping, code stubs
3. Flexibility in how you use it without overloading the number of methods you have to remember

Here's an example usage:

```ruby
let(:model_proxy) do
  MockProxy.new(email_client: {
    create_email: {
      receive: proc {}
    }
  })
end
before { allow(Model).to receive(:new).and_return model_proxy }
it 'should call receive' do
  proc = MockProxy.get(model_proxy, 'email_client.create_email.receive')
  expect(proc).to receive(:call)
  run_system_under_test
  MockProxy.update(mock_proxy, 'email_client.create_email.validate!') { true }
  MockProxy.observe(mock_proxy, 'email_client.create_email.send') do |to|
    expect(to).to eq 'stop@emailing.me'
  end
  run_system_under_test2
end
```

As you can see, the proc - which ends the proxy by calling the proc - can be used for anything. You can spy on the
call count and arguments, mock methods, or just stub out code you don't want executed. Because it doesn't make any
assumptions, it becomes very flexible. Simple, yet powerful, it's uses are infinite. Enjoy

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'mock_proxy'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install mock_proxy

## Usage

TODO: Write usage instructions here

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/mock_proxy. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
