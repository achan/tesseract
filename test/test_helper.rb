ENV["RAILS_ENV"] ||= "test"
ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"] ||= "test-primary-key-that-is-long-enough"
ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"] ||= "test-deterministic-key-long-enough"
ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"] ||= "test-key-derivation-salt-long-enough"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
