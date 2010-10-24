# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 0) do
  create_table "article_versions", :force => true do |t|
    t.integer  "article_id"
    t.datetime "version_from"
    t.datetime "version_to"
    t.string   "title"
    t.text     "body"
    t.datetime "updated_on"
    t.datetime "created_on"
    t.integer  "author_id"
    t.integer  "revisor_id"
  end

  create_table "articles", :force => true do |t|
    t.string   "title"
    t.text     "body"
    t.datetime "updated_on"
    t.datetime "created_on"
    t.integer  "author_id"
    t.integer  "revisor_id"
  end

  create_table "articles_documents", :id => false, :force => true do |t|
    t.integer "article_id"
    t.integer "document_id"
  end

  create_table "articles_documents_versions", :id => false, :force => true do |t|
    t.integer  "article_id"
    t.integer  "document_id"
    t.datetime "version_from"
    t.datetime "version_to"
  end

  create_table "articles_things", :id => false, :force => true do |t|
    t.integer "article_id"
    t.integer "thing_id"
  end

  create_table "articles_things_versions", :id => false, :force => true do |t|
    t.integer  "article_id"
    t.integer  "thing_id"
    t.datetime "version_from"
    t.datetime "version_to"
  end

  create_table "authors", :force => true do |t|
    t.integer "page_id"
    t.string  "name"
  end

  create_table "client_documents_versions", :id => false, :force => true do |t|
    t.integer  "client_id"
    t.integer  "document_id"
    t.datetime "version_from"
    t.datetime "version_to"
  end

  create_table "client_versions", :force => true do |t|
    t.integer  "client_id"
    t.integer  "project_id"
    t.string   "name",         :limit => 100
    t.datetime "version_from"
    t.datetime "version_to"
    t.integer  "thing_id"
  end

  create_table "clients", :force => true do |t|
    t.integer "project_id"
    t.string  "name",       :limit => 100
  end

  create_table "document_versions", :force => true do |t|
    t.integer  "document_id"
    t.datetime "version_from"
    t.datetime "version_to"
    t.string   "title"
    t.text     "body"
    t.datetime "updated_on"
    t.datetime "created_on"
    t.integer  "author_id"
    t.integer  "revisor_id"
    t.integer  "client_id"
    t.integer  "client_version_id"
  end

  create_table "documents", :force => true do |t|
    t.string   "title"
    t.text     "body"
    t.datetime "updated_on"
    t.datetime "created_on"
    t.integer  "author_id"
    t.integer  "revisor_id"
    t.integer  "client_id"
  end

  create_table "landmark_versions", :force => true do |t|
    t.integer  "landmark_id"
    t.string   "name"
    t.float    "latitude"
    t.float    "longitude"
    t.string   "doesnt_trigger_version"
    t.datetime "version_from"
    t.datetime "version_to"
  end

  add_index :landmark_versions, [:landmark_id, :version_from], :unique => true

  create_table "landmarks", :force => true do |t|
    t.string "name"
    t.float  "latitude"
    t.float  "longitude"
    t.string "doesnt_trigger_version"
  end

  create_table "locked_pages", :force => true do |t|
    t.integer "lock_version"
    t.string  "title", :limit => 255
    t.text    "body"
    t.string  "type", :limit => 255
  end

  create_table "locked_pages_revisions", :force => true do |t|
    t.integer  "page_id"
    t.integer  "lock_version"
    t.datetime "version_from"
    t.datetime "version_to"
    t.string   "title", :limit => 255
    t.text     "body"
    t.string   "version_type", :limit => 255
    t.datetime "updated_at"
  end

  add_index :locked_pages_revisions, [:page_id, :lock_version], :unique => true

  create_table "page_versions", :force => true do |t|
    t.integer  "page_id"
    t.datetime "version_from"
    t.datetime "version_to"
    t.string   "title", :limit => 255
    t.text     "body"
    t.datetime "created_on"
    t.datetime "updated_on"
    t.integer  "author_id"
    t.integer  "revisor_id"
  end

  add_index :page_versions, [:page_id, :version_from], :unique => true

  create_table "pages", :force => true do |t|
    t.string   "title", :limit => 255
    t.text     "body"
    t.datetime "created_on"
    t.datetime "updated_on"
    t.integer  "author_id"
    t.integer  "revisor_id"
  end

  create_table "people", :force => true do |t|
    t.string  "first_name"
    t.string  "last_name"
    t.integer "updated_by_id"
  end

  create_table "person_versions", :force => true do |t|
    t.integer  "person_id"
    t.datetime "version_from"
    t.datetime "version_to"
    t.integer  "updated_by_id"
    t.string   "first_name"
    t.string   "last_name"
  end

  add_index :person_versions, [:person_id, :version_from], :unique => true

  create_table "project_clients_versions", :id => false, :force => true do |t|
    t.integer  "project_id"
    t.integer  "client_id"
    t.datetime "version_from"
    t.datetime "version_to"
  end

  create_table "project_things_versions", :id => false, :force => true do |t|
    t.integer  "project_id"
    t.integer  "thing_id"
    t.datetime "version_from"
    t.datetime "version_to"
  end

  create_table "project_versions", :force => true do |t|
    t.integer  "project_id"
    t.string   "name",         :limit => 100
    t.datetime "version_to"
    t.datetime "version_from"
  end

  create_table "projects", :force => true do |t|
    t.string "name", :limit => 100
  end

  create_table "things", :force => true do |t|
    t.string  "title"
    t.text    "body"
    t.integer "project_id"
    t.integer "client_id"
  end

  create_table "widget_versions", :force => true do |t|
    t.integer  "widget_id"
    t.string   "name",         :limit => 50
    t.datetime "version_from"
    t.datetime "version_to"
    t.datetime "updated_at"
  end

  add_index :widget_versions, [:widget_id, :version_from], :unique => true

  create_table "widgets", :force => true do |t|
    t.string   "name",       :limit => 50
    t.string   "foo"
    t.datetime "updated_at"
  end
end
