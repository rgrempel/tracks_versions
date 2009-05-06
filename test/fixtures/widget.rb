class Widget < ActiveRecord::Base
  tracks_versions :sequence_name => 'widgets_seq', :association_options => {
    :dependent => :nullify, :order => 'version desc'
  }

  non_versioned_columns << 'foo'
end
