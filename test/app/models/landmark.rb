class Landmark < ActiveRecord::Base
  tracks_versions :if_changed => [ :name, :longitude, :latitude ]

end
