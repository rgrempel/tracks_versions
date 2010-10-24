require File.expand_path('../../test_helper', __FILE__)

# From acts_as_versioned

if ActiveRecord::Base.connection.supports_migrations?
  class NewThing < ActiveRecord::Base
    tracks_versions
  end

  class MigrationTest < ActiveSupport::TestCase
    self.use_transactional_fixtures = false
    setup do
      if ActiveRecord::Base.connection.respond_to?(:initialize_schema_information)
        ActiveRecord::Base.connection.initialize_schema_information
        ActiveRecord::Base.connection.update "UPDATE schema_info SET version = 0"
      else
        ActiveRecord::Base.connection.initialize_schema_migrations_table
        ActiveRecord::Base.connection.assume_migrated_upto_version(0)
      end

      NewThing.connection.drop_table "new_things" rescue nil
      NewThing.connection.drop_table "new_thing_versions" rescue nil
      NewThing.reset_column_information
    end

    def test_versioned_migration
      assert_raises(ActiveRecord::StatementInvalid) { NewThing.create :title => 'blah blah' }
      # take 'er up
      ActiveRecord::Migrator.up('test/fixtures/migrate')
      NewThing.reset_column_information
      t = NewThing.create :title => 'blah blah', :price => 123.45, :type => 'NewThing'
      assert_equal 1, t.versions.size

      # check that the price column has remembered its value correctly
      assert_equal t.price,  t.versions.first.price
      assert_equal t.title,  t.versions.first.title
      assert_equal t[:type], t.versions.first[:type]

      # make sure that the precision of the price column has been preserved
      assert_equal 7, NewThing::Version.columns.find{|c| c.name == "price"}.precision
      assert_equal 2, NewThing::Version.columns.find{|c| c.name == "price"}.scale

      # now lets take 'er back down
      ActiveRecord::Migrator.down('test/fixtures/migrate')
      assert_raises(ActiveRecord::StatementInvalid) { NewThing.create :title => 'blah blah' }
    end
  end
end
