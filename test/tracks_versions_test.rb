require File.join(File.dirname(__FILE__), 'test_helper')
require File.join(File.dirname(__FILE__), 'fixtures/page')
require File.join(File.dirname(__FILE__), 'fixtures/widget')
require File.join(File.dirname(__FILE__), 'fixtures/person')

## These tests are the ones that are specific to tracks_versions -- that is, not derived
## from acts_as_versioned or acts_as_versioned_association.

class TracksVersionsTest < ActiveSupport::TestCase
  fixtures :pages, :page_versions, :locked_pages, :locked_pages_revisions, :authors, :landmarks, :landmark_versions, :people, :person_versions
  set_fixture_class :page_versions => Page::VersionUpdate

  def test_sets_updated_by_id_on_create
    Person.current_user = people(:current)

    p = Person.create! :first_name => "Ryan", :last_name => "Rempel"
    
    assert !p.new_record?
    assert_equal 1, p.versions.size
    assert_instance_of Person.versioned_class, p.versions.first

    assert_equal people(:current).id, p.versions.first.updated_by_id, "Should have set updated_by_id on version"
  end

  def test_sets_updated_by_id_on_save
    Person.current_user = people(:current)

    p = people(:current)
    p.first_name = "bob"
    p.save

    assert !p.new_record?
    assert_equal 2, p.versions.size
    assert_instance_of Person.versioned_class, p.versions.last

    assert_equal people(:current).id, p.versions.last.updated_by_id, "Should have set updated_by_id on version"
  end
end
