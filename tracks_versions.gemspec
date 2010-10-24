Gem::Specification.new do |gem|
  gem.name    = 'tracks_versions'
  gem.version = '0.0.1'

  gem.summary = "Tracks versions of ActiveRecord records."
  gem.description = "Allows you to track versions of ActiveRecord records"

  gem.authors  = ['Ryan Rempel']
  gem.email    = 'rgrempel@gmail.com'
  gem.homepage = 'http://github.com/rgrempel/tracks_versions'

  gem.platform = Gem::Platform::RUBY

  gem.add_dependency 'rails', '>= 3'
  gem.add_dependency 'activemodel', '>= 3'

  gem.has_rdoc = true
  gem.rdoc_options.concat %W{--main README.rdoc -S -N}

  # list extra rdoc files
  gem.extra_rdoc_files = %W{
  }

  # ensure the gem is built out of versioned files
  gem.files = Dir['{bin,lib,man}/**/*', 'README*', 'LICENSE*', 'init.rb'] & `git ls-files -z`.split("\0")
end

