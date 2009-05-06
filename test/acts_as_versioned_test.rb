require File.join(File.dirname(__FILE__), 'test_helper')
require File.join(File.dirname(__FILE__), 'fixtures/page')
require File.join(File.dirname(__FILE__), 'fixtures/widget')

## These tests are a subset of the tests from acts_as_versioned -- I mainly wanted to
## see that I was passing the relevant test from there.

class ActsAsVersionedTest < ActiveSupport::TestCase
  fixtures :pages, :page_versions, :locked_pages, :locked_pages_revisions, :authors, :landmarks, :landmark_versions
  set_fixture_class :page_versions => Page::VersionUpdate

  def test_saves_versioned_copy
    p = Page.create! :title => 'first title', :body => 'first body'
    assert !p.new_record?
    assert_equal 1, p.versions.size
    assert_instance_of Page.versioned_class, p.versions.first
  end

  def test_rollback_with_version_number
    p = pages(:welcome)
    assert_equal 'Welcome to the weblog', p.title
    
    assert p.revert_to!(p.versions.first.version_from), "Couldn't revert to 23"
    assert_equal 'Welcome to the weblg', p.title
  end

  def test_versioned_class_name
    assert_equal 'Version', Page.versioned_class_name
    assert_equal 'LockedPageRevision', LockedPage.versioned_class_name
  end

  def test_versioned_class
    assert_equal Page::Version,                  Page.versioned_class
    assert_equal LockedPage::LockedPageRevision, LockedPage.versioned_class
  end

  def test_special_methods
    assert_nothing_raised { pages(:welcome).feeling_good? }
    assert_nothing_raised { pages(:welcome).versions.first.feeling_good? }
    assert_nothing_raised { locked_pages(:welcome).hello_world }
    assert_nothing_raised { locked_pages(:welcome).versions.first.hello_world }
  end

  def test_rollback_with_version_class
    p = pages(:welcome)
    assert_equal 'Welcome to the weblog', p.title
    assert_equal 2, p.versions.size, "Should have two versions"
    assert_equal 'Welcome to the weblog', p.versions.last.title, "Last version should be correct"
    assert_equal 'Welcome to the weblg', p.versions.first.title, "First version should have mistake"
    
    assert p.revert_to!(p.versions.first), "Couldn't revert to 23"
    assert_equal 'Welcome to the weblg', p.title
  end
  
  def test_rollback_fails_with_invalid_revision
    p = locked_pages(:welcome)
    assert !p.revert_to!(locked_pages(:thinking))
  end

  def test_saves_versioned_copy_with_options
    p = LockedPage.create! :title => 'first title'
    assert !p.new_record?
    assert_equal 1, p.versions.size
    assert_instance_of LockedPage.versioned_class, p.versions.first
  end
  
  def test_rollback_with_version_number_with_options
    p = locked_pages(:welcome)
    assert_equal 'Welcome to the weblog', p.title
    assert_equal 'LockedPage', p.versions.first.version_type
    
    assert p.revert_to!(p.versions.first.version_from), "Couldn't revert to 23"
    assert_equal 'Welcome to the weblg', p.title
    assert_equal 'LockedPage', p.versions.first.version_type
  end
  
  def test_rollback_with_version_class_with_options
    p = locked_pages(:welcome)
    assert_equal 'Welcome to the weblog', p.title
    assert_equal 'LockedPage', p.versions.first.version_type
    
    assert p.revert_to!(p.versions.first), "Couldn't revert to 1"
    assert_equal 'Welcome to the weblg', p.title
    assert_equal 'LockedPage', p.versions.first.version_type
  end
  
  def test_saves_versioned_copy_with_sti
    p = SpecialLockedPage.create! :title => 'first title'
    assert !p.new_record?
    assert_equal 1, p.versions.size
    assert_instance_of LockedPage.versioned_class, p.versions.first
    assert_equal 'SpecialLockedPage', p.versions.first.version_type
  end
  
  def test_rollback_with_version_number_with_sti
    p = locked_pages(:thinking)
    assert_equal 'So I was thinking', p.title
    
    assert p.revert_to!(p.versions.first.version_from), "Couldn't revert to 1"
    assert_equal 'So I was thinking!!!', p.title
    assert_equal 'SpecialLockedPage', p.versions.first.version_type
  end

  def test_lock_version_works_with_versioning
    p = locked_pages(:thinking)
    p2 = LockedPage.find(p.id)
    
    size = p.versions.size
    p.title = 'fresh title'
    p.save
    assert_equal size + 1, p.versions.size

    assert_raises(ActiveRecord::StaleObjectError) do
      p2.title = 'stale title'
      p2.save
    end
  end

  def test_version_if_condition
    p = Page.create! :title => "title"
    
    Page.feeling_good = false
    p.save
    assert_equal 1, p.versions(true).size
    Page.feeling_good = true
  end
  
  def test_version_if_condition2
    # set new if condition
    Page.class_eval do
      def new_feeling_good() title[0..0] == 'a'; end
      alias_method :old_feeling_good, :feeling_good?
      alias_method :feeling_good?, :new_feeling_good
    end
    
    p = Page.create! :title => "title"
    assert_equal 1, p.versions(true).size
    
    p.update_attributes(:title => 'new title')
    assert_equal 1, p.versions(true).size
    
    p.update_attributes(:title => 'a title')
    assert_equal 2, p.versions(true).size
    
    # reset original if condition
    Page.class_eval { alias_method :feeling_good?, :old_feeling_good }
  end
  
  def test_version_if_condition_with_block
    # set new if condition
    old_condition = Page.version_condition
    Page.version_condition = Proc.new { |page| page.title[0..0] == 'b' }
    
    p = Page.create! :title => "title"
    assert_equal 1, p.versions(true).size
    
    p.update_attributes(:title => 'a title')
    assert_equal 1, p.versions(true).size
    
    p.update_attributes(:title => 'b title')
    assert_equal 2, p.versions(true).size
    
    # reset original if condition
    Page.version_condition = old_condition
  end

  def assert_page_title(p, i, version_field = :version)
    p.title = "title#{i}"
    p.save
    assert_equal "title#{i}", p.title
    assert_equal (i+4), p.send(version_field)
  end
  
  def test_find_versions
    assert_equal 2, locked_pages(:welcome).versions.size
    assert_equal 1, locked_pages(:welcome).versions.find(:all, :conditions => ['title LIKE ?', '%weblog%']).length
    assert_equal 2, locked_pages(:welcome).versions.find(:all, :conditions => ['title LIKE ?', '%web%']).length
    assert_equal 0, locked_pages(:thinking).versions.find(:all, :conditions => ['title LIKE ?', '%web%']).length
    assert_equal 2, locked_pages(:welcome).versions.length
  end
  
  def test_has_many_through
    assert_equal [authors(:caged), authors(:mly)], pages(:welcome).authors
  end

  def test_has_many_through_with_custom_association
    assert_equal [authors(:caged), authors(:mly)], pages(:welcome).revisors
  end
  
  def test_versioned_records_should_belong_to_parent
    page = pages(:welcome)
    page_version = page.versions.last
    assert_equal page, page_version.page
  end
  
  def test_should_find_earliest_version
    assert_equal page_versions(:welcome_1).attributes, pages(:welcome).versions.earliest.attributes
  end
  
  def test_should_find_latest_version
    assert_equal page_versions(:welcome_2).attributes, pages(:welcome).versions.latest.attributes
  end
  
  def test_should_find_previous_version_class_method
    assert_equal page_versions(:welcome_1).attributes, page_versions(:welcome_2).previous.attributes
  end

  def test_should_find_previous_version_through_association
    assert_equal page_versions(:welcome_1).attributes, pages(:welcome).versions.before(page_versions(:welcome_2)).attributes
  end
  
  def test_should_find_next_version_class_method
    assert_equal page_versions(:welcome_2).attributes, page_versions(:welcome_1).next.attributes
  end
 
  def test_should_find_next_version_through_association
    assert_equal page_versions(:welcome_2).attributes, pages(:welcome).versions.after(page_versions(:welcome_1)).attributes
  end
end
