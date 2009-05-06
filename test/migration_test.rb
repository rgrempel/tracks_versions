require File.join(File.dirname(__FILE__), 'test_helper')

## From acts_as_versioned

if ActiveRecord::Base.connection.supports_migrations? 
  class NewThing < ActiveRecord::Base
    tracks_versions
  end

  class MigrationTest < ActiveSupport::TestCase
    self.use_transactional_fixtures = false

    def teardown
      NewThing.connection.drop_table "new_things" rescue nil
      NewThing.connection.drop_table "new_thing_versions" rescue nil
      NewThing.reset_column_information
    end
        
    def test_versioned_migration
      assert_raises(ActiveRecord::StatementInvalid) { NewThing.create :title => 'blah blah' }
      # take 'er up
      ActiveRecord::Migrator.up(File.dirname(__FILE__) + '/fixtures/migrations/')
      t = NewThing.create :title => 'blah blah'
      assert_equal 1, t.versions.size

      # now lets take 'er back down
      ActiveRecord::Migrator.down(File.dirname(__FILE__) + '/fixtures/migrations/')
      assert_raises(ActiveRecord::StatementInvalid) { NewThing.create :title => 'blah blah' }
    end
  end
end
