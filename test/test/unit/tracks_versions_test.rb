require File.expand_path('../../test_helper', __FILE__)

## These tests are the ones that are specific to tracks_versions -- that is, not derived
## from acts_as_versioned or acts_as_versioned_association.

class TracksVersionsTest < ActiveSupport::TestCase
  def test_sets_updated_by_id
    creator = Person.create! :first_name => "Joe", :last_name => "Johnson"
    Person.current_user = creator

    p = Person.create! :first_name => "Ryan", :last_name => "Rempel"

    assert !p.new_record?
    assert_equal 1, p.versions.size
    assert_instance_of Person.versioned_class, p.versions.earliest

    assert_equal creator.id, p.versions.last.updated_by_id, "Should have set updated_by_id on version when creating"

    Person.current_user = p
    p.first_name = "Joe"
    p.save!

    assert_equal 2, p.versions.size

    assert_equal p.id, p.versions.latest.updated_by_id, "Should have set updated_by_id on version when saving"
    assert_equal creator.id, p.versions.earliest.updated_by_id, "Should not get confused about first and last"  
  end
end
