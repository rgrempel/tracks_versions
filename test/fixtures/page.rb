class Page < ActiveRecord::Base
  belongs_to :author
  has_many   :authors,  :through => :versions, :order => 'name'
  belongs_to :revisor,  :class_name => 'Author', :foreign_key => "revisor_id"
  has_many   :revisors, :class_name => 'Author', :through => :versions, :order => 'name'

  tracks_versions :if => :feeling_good? do
    def self.included(base)
      base.cattr_accessor :feeling_good
      base.feeling_good = true
      base.belongs_to :author
      base.belongs_to :revisor, :class_name => 'Author', :foreign_key => "revisor_id"
    end
    
    def feeling_good?
      @@feeling_good == true
    end
  end
end

module LockedPageExtension
  def hello_world
    'hello_world'
  end
end

class LockedPage < ActiveRecord::Base
  tracks_versions :inheritance_column => :version_type, 
                  :foreign_key        => :page_id, 
                  :table_name         => :locked_pages_revisions, 
                  :class_name         => 'LockedPageRevision',
                  :extend             => LockedPageExtension
end

class SpecialLockedPage < LockedPage

end
