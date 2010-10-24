class AddVersionedTables < ActiveRecord::Migration
  def self.up
    create_table("new_things") do |t|
      t.column :title, :text
      t.column :price, :decimal, :precision => 7, :scale => 2
      t.column :type, :string
    end
    NewThing.create_versioned_table
  end

  def self.down
    NewThing.drop_versioned_table
    drop_table "new_things" rescue nil
  end
end
