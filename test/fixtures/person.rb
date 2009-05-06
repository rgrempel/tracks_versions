class Person < ActiveRecord::Base
  tracks_versions

  cattr_accessor :current_user

end
