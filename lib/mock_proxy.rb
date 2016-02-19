require "mock_proxy/version"

# A non-opinionated proxy object that has multiple uses. It can be used for mocking, spying,
# stubbing. Use as a dummy, double, fake, etc. Every test double type possible. How? Let's see
#
# Example, say you want to stub this scenario: Model.new.generate_email.validate!.send(to: email)
# That would have be 5-6 lines of stubbing. If this sounds like stub_chain, you're on the right track. It was removed in
# RSpec 3 (or 2?). It's similar to that but it does things differently
# First, it doesn't require you to use it in a stub
# Second, it's use of procs means you can define anything, a stub or a mock (expectation) or a spy or whatever you want
#
# To use MockProxy, initialize it with a hash. Each key is a method call. Each call either returns a new proxy or calls
# the proc. If the value is a proc, it calls it immediately with the args and block. If the value is a hash, it returns
# a new proxy with the value as the hash. MockProxy will warn if you don't use hashes or procs and will also warn if
# you did not define all the method calls (it won't automatically return itself for methods not defined in the hash)
#
# Example use:
#   let(:model_proxy) { MockProxy.new(receive_email: proc {}, generate_email: { validate!: { send: proc { |to| email } } }) }
#   before { allow(Model).to receive(:new).and_return model_proxy }
#   # ...
#   describe 'Model' do
#     it 'model also receives email' do
#       MockProxy.observe(model_proxy, :receive_email) do |message|
#         expect(message).to eq 'message'
#       end
#       run_system_under_test
#     end
#   end
#
# NOTE: You don't have to use only one mock proxy for all calls. You can break it up if you want to have more control
# over each method call
#
# Example:
#   let(:model_proxy) do
#     callback = proc do |type|
#       MockProxy.merge(generator_proxy, decorate: proc { |*args| method_call(type, *args) })
#       generator_proxy
#     end
#     MockProxy.new(generate_email: callback)
#   end
#   let(:generator_proxy) { MockProxy.new(validate!: { send: proc { |to| email } }) }
#
#
# @author Geoff Lee
# @since 0.1.0
#
class MockProxy
  # Retrieve the existing callback or callback tree at the specified key path
  #
  # NOTE: We freeze the hash so you cannot modify it
  #
  # Use case: Retrieve proc to mock
  #
  # @param [MockProxy] proxy existing proxy
  # @param [String, Symbol, #to_s, Array<String, Symbol, #to_s>] key_path the chain of methods or key path. Can be a
  #        dot delimited key path or an array of method names as strings or symbols
  # @return [Block]
  def self.get(proxy, key_path)
    get_and_validate_callback(proxy, key_path)
  end

  # Deep merges the callback tree, replacing existing values with new values.
  # Avoid using this method for one method change; prefer replace_at. It has clearer
  # intent and less chances to mess up. MockProxy.merge uses deep_merge under the hood and
  # can have unexpected behaviour. It also does not type check. Use at risk
  #
  # Use case: Reuse existing stub but with some different values
  #
  # @param [MockProxy] proxy existing proxy
  # @param [Hash] new_callback_hash new partial callback tree
  # @return [MockProxy] the original proxy object
  def self.merge(proxy, new_callback_hash)
    existing_callback_hash = proxy.instance_variable_get('@callback_hash')
    new_callback_hash = new_callback_hash.deep_stringify_keys
    new_callback_hash = existing_callback_hash.deep_merge(new_callback_hash).freeze
    proxy.instance_variable_set('@callback_hash', new_callback_hash)
    proxy
  end

  # Replaces the proc at the specified key path, but only if there was one there before.
  # Without creating new paths comes validation, including checking that this replaces an
  # existing proc, sort of like mkdir (without the -p option)
  #
  # Use case: Replace existing stub with a new proc without creating new method chains
  #
  # @param [MockProxy] proxy existing proxy
  # @param [String, Symbol, #to_s, Array<String, Symbol, #to_s>] key_path the chain of methods or key path. Can be a
  #        dot delimited key path or an array of method names as strings or symbols
  # @return [MockProxy] the original proxy object
  def self.replace_at(proxy, key_path, &block)
    set_callback(proxy, key_path, block)
    proxy
  end

  # Sets the proc at the specified key path, regardless if there was a proc there before.
  # No validation comes with automatic path creation, meaning the key path will be defined
  # it it hasn't already, sort of like mkdir -p
  #
  # Use case: Sets a new stub at specified key path while creating new method chains
  #
  # @param [MockProxy] proxy existing proxy
  # @param [String, Symbol, #to_s, Array<String, Symbol, #to_s>] key_path the chain of methods or key path. Can be a
  #        dot delimited key path or an array of method names as strings or symbols
  # @return [MockProxy] the original proxy object
  def self.set_at(proxy, key_path, &block)
    set_callback(proxy, key_path, block, false)
    proxy
  end

  # Add an observer to an existing proxy
  #
  # Use case: Observe method call without changing the existing callback's stubbed return value
  #
  # @param [MockProxy] proxy existing proxy
  # @param [String, Symbol, #to_s, Array<String, Symbol, #to_s>] key_path the chain of methods or key path. Can be a
  #        dot delimited key path or an array of method names as strings or symbols
  # @yieldparam [*args] args
  # @yieldreturn [optional]
  # @return [MockProxy] the original proxy object
  def self.observe(proxy, key_path, &block)
    callback = get_and_validate_callback(proxy, key_path)
    # Wrap existing callback, calling the provided block before it
    # Multiple calls to .observe will create a pyramid of callbacks, calling the observers before
    # eventually calling the existing callback
    new_callback = proc do |*args|
      block.call(*args)
      callback.call(*args)
    end
    set_callback(proxy, key_path, new_callback)
    proxy
  end

  # Wraps the existing callback with your block
  #
  # Use case: Get full control of the existing proc while running custom code
  #
  # @param [MockProxy] proxy existing proxy
  # @param [String, Symbol, #to_s, Array<String, Symbol, #to_s>] key_path the chain of methods or key path. Can be a
  #        dot delimited key path or an array of method names as strings or symbols
  # @yieldparam [*args, &block] args, original callback
  # @yieldreturn [optional]
  # @return [MockProxy] the original proxy object
  def self.wrap(proxy, key_path, &block)
    callback = get_and_validate_callback(proxy, key_path)
    # Wrap existing callback, calling the provided block before it
    # Multiple calls to .observe will create a pyramid of callbacks, calling the observers before
    # eventually calling the existing callback
    new_callback = proc do |*args|
      block.call(*args, &callback)
    end
    set_callback(proxy, key_path, new_callback)
    proxy
  end

  # @private
  # @param [MockProxy] proxy existing proxy
  # @param [String, Symbol, #to_s, Array<String, Symbol, #to_s>] key_path the chain of methods or key path. Can be a
  #        dot delimited key path or an array of method names as strings or symbols
  # @return [Proc] if proc found at key path
  # @raise [ArgumentError] if proc not found or hash found at key path
  def self.get_callback(proxy, key_path)
    key_paths = key_path.is_a?(Array) ? key_path.map(&:to_s) : key_path.split('.')
    existing_callback_hash = proxy.instance_variable_get('@callback_hash')
    key_paths.reduce(existing_callback_hash) do |callback_hash, key|
      if callback_hash && callback_hash[key]
        callback_hash[key]
      else
        fail ArgumentError, "The existing callback tree does not contain the full key path you provided. We stopped at #{key} and the callback tree looks like this: #{existing_callback_hash}"
      end
    end
  end
  private_class_method :get_callback

  # @private
  # @param [MockProxy] proxy existing proxy
  # @param [String, Symbol, #to_s, Array<String, Symbol, #to_s>] key_path the chain of methods or key path. Can be a
  #        dot delimited key path or an array of method names as strings or symbols
  # @return [Proc] if proc found at key path
  # @raise [ArgumentError] if proc not found or hash found at key path
  def self.get_and_validate_callback(proxy, key_path)
    callback = get_callback(proxy, key_path)
    return callback if callback.is_a?(Proc)
    fail ArgumentError, "The existing callback tree contains the full key path you provided but continues going (i.e. no proc at exact key path). If you want to shorten the callback tree, use MockProxy.set_at. The callback tree looks like this: #{proxy.instance_variable_get('@callback_hash')}"
  end
  private_class_method :get_and_validate_callback

  # @private
  # @param [MockProxy] proxy existing proxy
  # @param [String, Symbol, #to_s, Array<String, Symbol, #to_s>] key_path the chain of methods or key path. Can be a
  #        dot delimited key path or an array of method names as strings or symbols
  # @param [Proc] proc the new proc to replace the existing proc
  # @param [Bool] validate true will throw error if nil at any part of key path, false to
  #        create key path if missing (mkdir vs mkdir -p) (Defaults: true)
  # @return [MockProxy] if proc existed at key path
  # @raise [ArgumentError] if proc not found or hash found at key path
  def self.set_callback(proxy, key_path, proc, validate = true)
    # Validate by checking if proc exists at key path
    get_and_validate_callback(proxy, key_path) if validate
    # Set callback at key path, validating if set
    key_paths = key_path.is_a?(Array) ? key_path.map(&:to_s) : key_path.to_s.split('.')
    copied_callback_hash = proxy.instance_variable_get('@callback_hash').clone
    key_paths.reduce(copied_callback_hash) do |callback_hash, key|
      if !callback_hash || !callback_hash[key]
        if validate
          fail ArgumentError, "The existing callback tree does not contain the full key path you provided. We stopped at #{key} and the callback tree looks like this: #{copied_callback_hash}"
        else
          callback_hash[key] = {}
        end
      end
      if callback_hash[key].is_a?(Proc)
        callback_hash[key] = proc
      else
        callback_hash[key]
      end
    end
    proxy.instance_variable_set('@callback_hash', copied_callback_hash)
  end
  private_class_method :set_callback

  # @param [Hash] callback_hash the tree of chained method calls
  def initialize(callback_hash)
    @callback_hash = callback_hash.deep_stringify_keys.freeze
  end

  # @private
  def method_missing(name, *args, &block)
    current = @callback_hash[name.to_s]
    if current.is_a?(Proc)
      current.call(*args, &block)
    else
      if !current.is_a?(Proc) && !current.is_a?(Hash)
        fail "Missing method #{name}. Please add this definition to your mock proxy"
      end
      MockProxy.new(current.freeze)
    end
  end
end
