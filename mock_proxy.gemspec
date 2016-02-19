# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'mock_proxy/version'

Gem::Specification.new do |spec|
  spec.name          = "mock_proxy"
  spec.version       = MockProxy::VERSION
  spec.authors       = ["matrinox"]
  spec.email         = ["geofflee25@gmail.com"]

  spec.summary       = "A proxy that can be used to stub method chains and more!"
  spec.description   = "Remember when RSpec had stub_chain? They removed it for good reasons but sometimes you just need it.
  Well, here it is, a proxy object. It doesn't actually mock anything for you (the name is just catchy) so you need to do that.
  But that actually comes with a lot of benefits:
  1) It's compatable with any testing framework
  2) You can use it for purposes other than testing, e.g. prototyping, code stubs
  3) Flexibility in how you use it without overloading the number of methods you have to remember

  Here's an example usage:
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

  As you can see, the proc - which ends the proxy by calling the proc - can be used for anything. You can spy on the
  call count and arguments, mock methods, or just stub out code you don't want executed. Because it doesn't make any
  assumptions, it becomes very flexible. Simple, yet powerful, it's uses are infinite. Enjoy"
  spec.homepage      = "https://github.com/matrinox/MockProxy"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
end
