# Include this file in your test by copying the following line to your test:
#   require File.expand_path(File.dirname(__FILE__) + "/test_helper")

$:.unshift(File.dirname(__FILE__) + '/../lib')
RAILS_ROOT = File.dirname(__FILE__)

require 'rubygems'
require 'test/unit'
require 'active_record'
require 'active_record/fixtures'
require 'action_controller'
require 'action_view'
require 'test_help'

require "#{File.dirname(__FILE__)}/../init"

config = YAML::load(IO.read(File.dirname(__FILE__) + '/database.yml'))
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/debug.log")
ActiveRecord::Base.configurations = {'test' => config[ENV['DB'] || 'sqlite3']}
ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations['test'])

load(File.dirname(__FILE__) + "/schema.rb") if File.exist?(File.dirname(__FILE__) + "/schema.rb")

ActiveSupport::TestCase.fixture_path = File.dirname(__FILE__) + "/fixtures/"
$LOAD_PATH.unshift(ActiveSupport::TestCase.fixture_path)

class ActiveSupport::TestCase #:nodoc:
  cattr_accessor :current_time
  self.current_time = Time.now

  def create_fixtures(*table_names)
    if block_given?
      Fixtures.create_fixtures(ActiveSupport::TestCase.fixture_path, table_names) { yield }
    else
      Fixtures.create_fixtures(ActiveSupport::TestCase.fixture_path, table_names)
    end
  end

  # Turn off transactional fixtures if you're working with MyISAM tables in MySQL
  self.use_transactional_fixtures = false
  
  # Instantiated fixtures are slow, but give you @david where you otherwise would need people(:david)
  self.use_instantiated_fixtures  = false

  # Add more helper methods to be used by all tests here...

end

# This is to help set up fixtures
def days_ago days
  ActiveSupport::TestCase.current_time.ago(days.days).to_formatted_s(:db)
end
