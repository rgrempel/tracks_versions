class Person < ActiveRecord::Base
  tracks_versions :version_updated_by => lambda {Person.current_user}

  cattr_accessor :current_user

end
