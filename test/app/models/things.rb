# predefined as it didn't like some of the circular references
# IE if document has_many articles but articles wasn't yet loaded
# But can't move articles before documents because articles also
# references documents!
class Document < ActiveRecord::Base; end
class Thing < ActiveRecord::Base; end
class Article < ActiveRecord::Base; end
class Client < ActiveRecord::Base; end
class Project < ActiveRecord::Base; end

class Document < ActiveRecord::Base
  has_many :articles_documents
  has_many :articles, :through => :article_documents

  belongs_to :author
  belongs_to :client

  tracks_versions :associations => [:articles, :client]

end

class Article < ActiveRecord::Base
  has_many :articles_documents
  has_many :documents, :through => :articles_documents

  has_many :articles_things
  has_many :things, :through => :articles_things

  belongs_to :author

  tracks_versions :associations => [:documents, :things]

end

class ArticlesDocument < ActiveRecord::Base
  belongs_to :article
  belongs_to :document

  tracks_versions :assocations => [:article, :document]
end

class Thing < ActiveRecord::Base
  has_many :article_things
  has_many :articles, :through => :articles_things

  belongs_to :project
  belongs_to :client

end

class ArticlesThing < ActiveRecord::Base
  belongs_to :article
  belongs_to :thing

  tracks_versions :associations => [:article]

end

class Client < ActiveRecord::Base
  belongs_to :project
  has_one :document
  has_one :thing

  tracks_versions :associations => [:project, :document, :thing]

end

class Project < ActiveRecord::Base
  has_many :clients
  has_many :things

  tracks_versions :associations => [:clients, :things]

end
