class Widget < ActiveRecord::Base
  tracks_versions :sequence_name => 'widgets_seq', :association_options => {
    :order => 'version_from desc'
  }

  non_versioned_columns << 'foo'
end
