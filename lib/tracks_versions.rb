module TracksVersions
  def self.append_features base
    super
    base.extend(ClassMethods)
  end

  module ClassMethods
    def tracks_versions options={}, &extension
      return if self.included_modules.include?(TracksVersions::TracksVersionsInstanceMethods)

      class_eval do
        extend TracksVersions::TracksVersionsClassMethods

        cattr_accessor :versioned_class_name,
                       :versioned_update_class_name,
                       :versioned_foreign_key,
                       :versioned_table_name,
                       :versioned_inheritance_column,
                       :version_condition,
                       :non_versioned_columns,
                       :versioned_associations

        self.versioned_class_name         = options[:class_name]  || "Version"
        self.versioned_update_class_name  = "VersionUpdate"
        self.versioned_foreign_key        = options[:foreign_key] || self.to_s.foreign_key
        self.versioned_table_name         = options[:table_name]  || "#{table_name_prefix}#{base_class.name.demodulize.underscore}_versions#{table_name_suffix}"
        self.versioned_inheritance_column = options[:inheritance_column] || "versioned_#{inheritance_column}"
        self.version_condition            = options[:if] || true
        self.non_versioned_columns        = [self.primary_key, inheritance_column, 'version_from', 'version_to', 'lock_version', versioned_inheritance_column]
        self.versioned_associations       = options[:versioned_associations] ? [options[:versioned_associations]].flatten : []

        # Set up a module to extend the class and its version classes, based on the block given
        if block_given?
          extension_module_name = "#{versioned_class_name}Extension"

          silence_warnings do
            self.const_set(extension_module_name, Module.new(&extension))
          end
            
          options[:extend] = self.const_get(extension_module_name)
        end                                                                                           

        include options[:extend] if options[:extend].is_a?(Module)

        # Set up the has_many for the versions
        has_many :versions, {
          :class_name  => "#{self.to_s}::#{versioned_class_name}",
          :foreign_key => versioned_foreign_key,
          :order       => 'version_from ASC',
          :extend      => MethodsForHasManyAssociation,
        }.merge(options[:association_options] || {})

        # Set up the has_many for the updateable versions
        has_many :versions_for_update, {
          :class_name  => "#{self.to_s}::#{versioned_update_class_name}",
          :foreign_key => versioned_foreign_key,
          :order       => 'version_from ASC',
          :extend      => MethodsForHasManyAssociation,
        }.merge(options[:association_options] || {})

        # Set up the call backs 
        after_create   :save_version
        after_update   :possibly_save_version        
        after_destroy  :record_deletion
      end

      # Create the versioned model
      const_set(versioned_class_name, Class.new(ActiveRecord::Base))

      versioned_class.cattr_accessor :original_class
      versioned_class.original_class = self
      versioned_class.set_primary_key versioned_foreign_key
      versioned_class.set_table_name versioned_table_name

      versioned_class.belongs_to self.to_s.demodulize.underscore.to_sym, {
        :class_name  => "::#{self.to_s}", 
        :foreign_key => versioned_foreign_key
      }

      versioned_class.send :include, options[:extend] if options[:extend].is_a?(Module)
      versioned_class.send :include, TracksVersions::InstanceMethodsForVersionClasses
      versioned_class.send :extend, TracksVersions::ClassMethodsForVersionClasses

      # Create the update model
      const_set(versioned_update_class_name, Class.new(ActiveRecord::Base))

      versioned_update_class.cattr_accessor :original_class
      versioned_update_class.original_class = self
      versioned_update_class.set_table_name versioned_table_name

      versioned_update_class.belongs_to self.to_s.demodulize.underscore.to_sym, {
        :class_name  => "::#{self.to_s}", 
        :foreign_key => versioned_foreign_key            
      }

      versioned_update_class.send :include, options[:extend] if options[:extend].is_a?(Module)
      versioned_update_class.send :include, TracksVersions::InstanceMethodsForVersionClasses
      versioned_update_class.send :extend, TracksVersions::ClassMethodsForVersionClasses

      # Now, set up the versioned associations
      versioned_class.class_eval do
        original_class.versioned_associations.each do |association_name|
          assoc = original_class.reflect_on_association(association_name)

          case assoc.association_macro
            when :has_many    # What about :through?
              has_many association_name,
                :class_name => assoc.klass.to_s + "::Version",
                :conditions => assoc.options[:conditions], 
                :order => assoc.options[:order],              
                :foreign_key => assoc.association_foreign_key,
                :include => assoc.options[:include]
 
                # :extend => ?,                                # may want something here eventually
                # :group => ?,   # What could group mean here?
                # :limit => ?,   # If we are going to support the limit, would need to do it later ...
                # :offset => ?,  # Again, would need to support this later, if at all ...
                # :select => ?,  # Perhaps would work with table rewriting
                # :as => ?,      # For polymporhpic -- how would that work?
                # :through => ?,     # Hmm ...
                # :source => ?,      # Hmm ...
                # :source_type => ?, # Hmm ...
                # :uniq => ?         # Hmm ...
                    
            when :belongs_to
              has_many association_name,
                :class_name => assoc.klass.to_s + "::Version",
                :conditions => assoc.options[:conditions],
                :order => assoc.options[:order],
                :foreign_key => assoc.association_foreign_key,
                :include => assoc.options[:include],
                :polymorphic => assoc.options[:polymorphic]

            when :has_one
              has_one association_name,
                :class_name => assoc.klass.to_s + "::Version",
                :conditions => assoc.options[:conditions],
                :order => assoc.options[:order],
                :foreign_key => assoc.association_foreign_key,
                :include => assoc.options[:include],
                :as => assoc.options[:as]

            else
              raise "tracks_version does not support #{assoc.association_macro.to_s} associations"
          end 
        end
      end

      include TracksVersions::TracksVersionsInstanceMethods
    end
  end

  module ClassMethodsForVersionClasses
    def reloadable?
      false
    end

    # find first version before the given version
    def before(version)
      id = version.is_a?(original_class.versioned_class) ? version.id : version.send(original_class.versioned_foreign_key)
      find :first, 
           :order => 'version_from DESC',
           :conditions => ["#{original_class.versioned_foreign_key} = ? and version_from < ?", id, version.version_from]
    end
            
    # find first version after the given version.
    def after(version)
      id = version.is_a?(original_class.versioned_class) ? version.id : version.send(original_class.versioned_foreign_key)
      result = find :first, 
                    :order => 'version_from ASC',
                    :conditions => ["#{original_class.versioned_foreign_key} = ? and version_from > ?", id, version.version_from]
    end
  end
        
  module InstanceMethodsForVersionClasses    
    def previous
      self.class.before(self)
    end
            
    def next
      self.class.after(self)
    end

    def to_version
      if self.is_a?(original_class.versioned_class)
        self
      elsif self.is_a?(original_class.versioned_update_class)
        original_class.versioned_class.find :first, 
                                            :conditions => ["#{original_class.versioned_foreign_key} = ? AND version_from = ?", self.send(original_class.versioned_foreign_key), self.version_from]
      else
        nil
      end
    end

    def to_version_update
      if self.is_a?(original_class.versioned_update_class)
        self
      elsif self.is_a?(original_class.versioned_class)
        original_class.versioned_update_class.find :first, 
                                                   :conditions => ["#{original_class.versioned_foreign_key} = ? AND version_from = ?", self.id, self.version_from]
      end
    end
  end

  # These methods are included in the has_many association of the version class and the version_update class
  module MethodsForHasManyAssociation
    # finds earliest version of this record
    def earliest
      find(:first, :order => "version_from ASC")
    end
              
    # find latest version of this record
    def latest
      find(:first, :order => 'version_from DESC')
    end

    # Finds the version of this record as of a particular date
    def as_of what_date
      # We save the version_as_of to apply to any associations. Note that we may need to reset this in code
      # if we want to see different models as of different dates, since it is basically global.
      self.version_as_of = what_date
      result = find :first, 
                    :conditions => ['version_from <= ?', what_date], 
                    :order => "version_from DESC"
      result = nil if result && result.version_to && result.version_to <= what_date
      result
    end
  end

  # These are methods added to the main model
  module TracksVersionsClassMethods
    # Finds a specific version of a specific row of this model
    def find_version(id, version)
      self.version_as_of = version
      find_versions(id, 
        :conditions => ["#{versioned_foreign_key} = ? AND version_from < ?", id, version], 
        :limit => 1,
        :order => "version_from DESC").first
    end
        
    # Finds versions of a specific model.  Takes an options hash like <tt>find</tt>
    def find_versions(id, options = {})
      versioned_class.find :all, {
        :conditions => ["#{versioned_foreign_key} = ?", id],
        :order      => 'version_from ASC' 
      }.merge(options)
    end

    # Returns an array of columns that are versioned.  See non_versioned_columns
    def versioned_columns
      self.columns.select { |c| !non_versioned_columns.include?(c.name) }
    end
    
    # Returns an instance of the dynamic versioned model
    def versioned_class
      const_get versioned_class_name
    end

    # Returns an instance of the versioned model for update
    def versioned_update_class
      const_get versioned_update_class_name
    end

    # Rake migration task to create the versioned table using options passed to acts_as_versioned
    def create_versioned_table(create_table_options = {})
      self.connection.create_table(versioned_table_name, create_table_options) do |t|
        t.column versioned_foreign_key, :integer
        t.column :version_from, :datetime
        t.column :version_to, :datetime
      end

      [versioned_foreign_key, :version_from, :version_to].each do |col|
        self.connection.add_index versioned_table_name, col
      end
            
      self.versioned_columns.each do |col| 
        self.connection.add_column versioned_table_name, col.name, col.type, {
          :limit => col.limit, 
          :default => col.default
        }
      end
        
      if type_col = self.columns_hash[inheritance_column]
        self.connection.add_column versioned_table_name, versioned_inheritance_column, type_col.type, 
          :limit => type_col.limit, 
          :default => type_col.default
      end
    end
 
    def drop_versioned_table
      self.connection.drop_table versioned_table_name
    end
  end

  module TracksVersionsInstanceMethods
    def save_version?
      version_condition_met? && changed?
    end
                                  
    def version_condition_met?
      case
        when version_condition.is_a?(Symbol)
          send(version_condition)
        when version_condition.respond_to?(:call) && (version_condition.arity == 1 || version_condition.arity == -1)
          version_condition.call(self)
        else
          version_condition
      end
    end

    def possibly_save_version
      save_version if save_version?
    end

    def save_version
      transaction do
        time = Time.now

        previous = self.versions_for_update.latest
        if previous
          previous.version_to = time
          previous.save!
        end

        rev = self.class.versioned_update_class.new
        self.clone_versioned_model(self, rev)
        rev.send("#{self.class.versioned_foreign_key}=", self.id)

        rev.updated_by_id = Person.current_user.id if rev.respond_to?(:updated_by_id=) && Person.current_user

        rev.version_from = time
        rev.save!
      end

      self.versions(true)
      self.versions_for_update(true)
      true
    end

    def record_deletion
      previous = self.versions_for_update.latest || begin 
        self.save_version
        self.versions_for_update.latest
      end

      raise "Should have saved previous version" unless previous

      previous.version_to = Time.now
      previous.save!
      true
    end

    # Reverts a model to a given version.  Takes either a date or an instance of the versioned model
    def revert_to(version)
      if version.is_a?(self.class.versioned_class) || version.is_a?(self.class.versioned_update_class)
        return false unless version.send(self.class.versioned_foreign_key) == self.id and !version.new_record?
      else
        return false unless version = versions.as_of(version)
      end
      self.clone_versioned_model(version, self)
      true
    end

    def revert_to!(version)
      revert_to(version) ? save : false
    end

    # Returns an array of attribute keys that are versioned.  See non_versioned_columns
    def versioned_attributes
      self.attributes.keys.select { |k| !self.class.non_versioned_columns.include?(k) }
    end

    # Clones a model.  Used when saving a new version or reverting a model's version.
    def clone_versioned_model(orig_model, new_model)
      self.versioned_attributes.each do |key|
        new_model.send("#{key}=", orig_model.send(key)) if orig_model.has_attribute?(key)
      end
          
      if orig_model.is_a?(self.class.versioned_class) || orig_model.is_a?(self.class.versioned_update_class)
        new_model[new_model.class.inheritance_column] = orig_model[self.class.versioned_inheritance_column]
      elsif new_model.is_a?(self.class.versioned_class) || new_model.is_a?(self.class.versioned_update_class)
        new_model[self.class.versioned_inheritance_column] = orig_model[orig_model.class.inheritance_column]
      end
    end
  end
end

ActiveRecord::Base.class_eval do
  include TracksVersions

  cattr_accessor :version_as_of
  self.version_as_of = nil
end
