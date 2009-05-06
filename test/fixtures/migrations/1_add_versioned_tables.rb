class AddVersionedTables < ActiveRecord::Migration
  def self.up
    create_table("new_things") do |t|
      t.column :title, :text
    end
    NewThing.create_versioned_table
  end
  
  def self.down
    NewThing.drop_versioned_table
    drop_table "new_things" rescue nil
  end
end
