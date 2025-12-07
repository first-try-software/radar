ENV['RAILS_ENV'] ||= 'test'
ENV['SECRET_KEY_BASE'] ||= 'test_key_base'
ENV['RAILS_TEST_MASTER_KEY'] ||= '0' * 32
ENV['RAILS_MASTER_KEY'] ||= '0' * 32
ENV['ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY'] ||= '0' * 32
ENV['ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY'] ||= '0' * 32
ENV['ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT'] ||= 'salt'
require File.expand_path('../config/environment', __dir__)
abort("The Rails environment is running in production mode!") if Rails.env.production?

require 'spec_helper'
require 'rspec/rails'

ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  config.use_transactional_fixtures = true
end
