$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'rubygems'
require 'test/unit/notification'
require 'test/unit'
require 'active_record'

require File.expand_path(File.dirname(__FILE__) + '/../../field_defs/init')
require File.expand_path(File.dirname(__FILE__) + '/../../acts_as_audited/init')
require File.dirname(__FILE__) + '/../init.rb'
require 'audit'

require 'active_record/fixtures'


# ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + "/debug.log")
ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :dbfile => ":memory:")

load(File.dirname(__FILE__) + "/fixtures/test_schema.rb")

# Test::Unit::TestCase.fixture_path = File.dirname(__FILE__) + "/fixtures/"
$LOAD_PATH.unshift(File.dirname(__FILE__) + "/fixtures/")

require File.expand_path(File.dirname(__FILE__) + '/../../field_defs/init')

# load model
require File.join(File.dirname(__FILE__), 'fixtures/test_models.rb')

class Test::Unit::TestCase #:nodoc:
  def create_fixtures(*table_names)
    if block_given?
      Fixtures.create_fixtures(Test::Unit::TestCase.fixture_path, table_names) { yield }
    else
      Fixtures.create_fixtures(Test::Unit::TestCase.fixture_path, table_names)
    end
  end

  # Turn off transactional fixtures if you're working with MyISAM tables in MySQL
  # self.use_transactional_fixtures = true
  
  # Instantiated fixtures are slow, but give you @david where you otherwise would need people(:david)
  # self.use_instantiated_fixtures  = false

  # Add more helper methods to be used by all tests here...
  
  # http://project.ioni.st/post/217#post-217
  #
  #  def test_new_publication
  #    assert_difference(Publication, :count) do
  #      post :create, :publication => {...}
  #      # ...
  #    end
  #  end
  # 
  def assert_difference(object, method = nil, difference = 1)
    initial_value = object.send(method)
    yield
    assert_equal initial_value + difference, object.send(method), "#{object}##{method}"
  end
  
  def assert_no_difference(object, method, &block)
    assert_difference object, method, 0, &block
  end
  
end