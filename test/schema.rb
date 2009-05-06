ActiveRecord::Schema.define(:version => 0) do

  ### Tables for own tests
  
  create_table :people, :force => true do |t|
    t.column :first_name, :string 
    t.column :last_name, :string
    t.column :updated_by_id, :integer
  end

  create_table :person_versions, :force => true do |t|
    t.column :person_id, :integer
    t.column :version_from, :datetime
    t.column :version_to, :datetime
    t.column :updated_by_id, :integer
    t.column :first_name, :string
    t.column :last_name, :string
  end

  ### Tables for test from acts_as_versioned

  create_table :pages, :force => true do |t|
    t.column :title, :string, :limit => 255
    t.column :body, :text
    t.column :updated_on, :datetime
    t.column :author_id, :integer
    t.column :revisor_id, :integer
  end

  create_table :page_versions, :force => true do |t|
    t.column :page_id, :integer
    t.column :version_from, :datetime
    t.column :version_to, :datetime
    t.column :title, :string, :limit => 255
    t.column :body, :text
    t.column :updated_on, :datetime
    t.column :author_id, :integer
    t.column :revisor_id, :integer
  end
  
  create_table :authors, :force => true do |t|
    t.column :page_id, :integer
    t.column :name, :string
  end
  
  create_table :locked_pages, :force => true do |t|
    t.column :lock_version, :integer
    t.column :title, :string, :limit => 255
    t.column :type, :string, :limit => 255
  end

  create_table :locked_pages_revisions, :force => true do |t|
    t.column :page_id, :integer
    t.column :version_from, :datetime
    t.column :version_to, :datetime
    t.column :title, :string, :limit => 255
    t.column :version_type, :string, :limit => 255
    t.column :updated_at, :datetime
  end

  create_table :widgets, :force => true do |t|
    t.column :name, :string, :limit => 50
    t.column :foo, :string
    t.column :updated_at, :datetime
  end

  create_table :widget_versions, :force => true do |t|
    t.column :widget_id, :integer
    t.column :name, :string, :limit => 50
    t.column :version_from, :datetime
    t.column :version_to, :datetime
    t.column :updated_at, :datetime
  end
  
  create_table :landmarks, :force => true do |t|
    t.column :name, :string
    t.column :latitude, :float
    t.column :longitude, :float
  end

  create_table :landmark_versions, :force => true do |t|
    t.column :landmark_id, :integer
    t.column :name, :string
    t.column :latitude, :float
    t.column :longitude, :float
    t.column :version_from, :datetime
    t.column :version_to, :datetime
  end

  #### Tables for tests from acts_as_versioned_association

  create_table :articles, :force => true do |t|
    t.column :title, :string, :limit => 255
    t.column :body, :text
    t.column :updated_on, :datetime
    t.column :created_on, :datetime    
    t.column :author_id, :integer
    t.column :revisor_id, :integer
  end
  
  create_table :article_versions, :force => true do |t|
    t.column :article_id, :integer
    t.column :version_from, :datetime
    t.column :version_to, :datetime
    t.column :title, :string, :limit => 255
    t.column :body, :text
    t.column :updated_on, :datetime
    t.column :created_on, :datetime    
    t.column :author_id, :integer
    t.column :revisor_id, :integer  
  end  

  create_table :things, :force => true do |t|
    t.column :title, :string, :limit => 255
    t.column :body, :text
    t.column :project_id, :integer
    t.column :client_id, :integer
  end

  create_table :articles_things, :force => true, :id => false do |t|
    t.column :article_id, :integer
    t.column :thing_id, :integer
  end

  create_table :articles_things_versions, :force => true, :id => false do |t|
    t.column :article_id, :integer
    t.column :thing_id, :integer
    t.column :version_from, :datetime
    t.column :version_to, :datetime
  end

  create_table :documents, :force => true do |t|
    t.column :title, :string, :limit => 255
    t.column :body, :text
    t.column :updated_on, :datetime
    t.column :created_on, :datetime    
    t.column :author_id, :integer
    t.column :revisor_id, :integer  
    t.column :client_id, :integer
  end
  
  create_table :document_versions, :force => true do |t|
    t.column :document_id, :integer  
    t.column :version_from, :datetime
    t.column :version_to, :datetime
    t.column :title, :string, :limit => 255
    t.column :body, :text
    t.column :updated_on, :datetime
    t.column :created_on, :datetime    
    t.column :author_id, :integer
    t.column :revisor_id, :integer  
    t.column :client_id, :integer    
    t.column :client_version_id, :integer
  end 
  
  create_table :articles_documents, :force => true, :id => false do |t|
    t.column :article_id, :integer
    t.column :document_id, :integer
  end    
    
  create_table :articles_documents_versions, :force => true, :id => false do |t|
    t.column :article_id, :integer
    t.column :document_id, :integer
    t.column :version_from, :datetime
    t.column :version_to, :datetime
  end  
  
  create_table :clients, :force => true do |t|
    t.column :project_id, :integer
    t.column :name, :string, :limit => 100
  end

  create_table :client_versions, :force => true do |t|
    t.column :client_id, :integer    
    t.column :project_id, :integer
    t.column :name, :string, :limit => 100
    t.column :version_from, :datetime
    t.column :version_to, :datetime
    t.column :thing_id, :integer
  end

  create_table :client_documents_versions, :force => true, :id => false do |t|
    t.column :client_id, :integer
    t.column :document_id, :integer
    t.column :version_from, :datetime
    t.column :version_to, :datetime
  end

  create_table :projects, :force => true do |t|
    t.column :name, :string, :limit => 100
  end

  create_table :project_versions, :force => true do |t|
    t.column :project_id, :integer    
    t.column :name, :string, :limit => 100
    t.column :version_to, :datetime
    t.column :version_from, :datetime   
  end
  
  create_table :project_clients_versions, :force => true, :id => false do |t|
    t.column :project_id, :integer
    t.column :client_id, :integer
    t.column :version_from, :datetime
    t.column :version_to, :datetime
  end

  create_table :project_things_versions, :force => true, :id => false do |t|
    t.column :project_id, :integer
    t.column :thing_id, :integer
    t.column :version_from, :datetime
    t.column :version_to, :datetime
  end

end
