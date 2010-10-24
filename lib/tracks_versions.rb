# Note that this is substantially based on acts_as_versioned.
# The main differences are that I am using version_from and version_to
# dates to mark the versions, rather than a version number. The main purpose
# is to permit reconstruction of associations that were valid as of a particular
# date without requiring any redundant saving of versions up-front. There are
# a few other differences here and there.

# The original acts_as_versioned code has the following licence.

# Copyright (c) 2005 Rick Olson
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

require 'active_support/concern'

module TracksVersions
  VERSION   = "0.0.1"
  # Unlike AAV, we don't use set_new_version
  CALLBACKS = [:save_version, :save_version?]

  def tracks_versions options={}, &extension
    return if self.included_modules.include?(TracksVersions::Behaviors)

    cattr_accessor :versioned_class_name, :versioned_foreign_key, :versioned_table_name, :versioned_inheritance_column,
                   :version_column, :max_version_limit, :track_altered_attributes, :version_condition, :version_sequence_name, :non_versioned_columns,
                   :version_association_options, :version_if_changed

    # These are not found in AAV
    cattr_accessor :versioned_update_class_name, :version_update_association_options, :version_updated_by

    self.versioned_class_name         = options[:class_name]  || "Version"
    # We also use a class for updating versions with the version_to ... if I recall correctly, we need to set
    # the primary key differently in order to do that.
    self.versioned_update_class_name  = options[:update_class_name] || "VersionUpdate"

    self.versioned_foreign_key        = options[:foreign_key] || self.to_s.foreign_key
    self.versioned_table_name         = options[:table_name]  || "#{table_name_prefix}#{base_class.name.demodulize.underscore}_versions#{table_name_suffix}"
    self.versioned_inheritance_column = options[:inheritance_column] || "versioned_#{inheritance_column}"
    self.version_sequence_name        = options[:sequence_name]
    self.max_version_limit            = options[:limit].to_i
    self.version_condition            = options[:if] || true

    # Our list of non_versioned columns is a little different than AAV's
    # TODO: Should really make 'version_from' and 'version_to' configurable.
    self.non_versioned_columns        = [self.primary_key, inheritance_column, 'version_from', 'version_to', 'lock_version', versioned_inheritance_column] + options[:non_versioned_columns].to_a.map(&:to_s)

    # AAV defaults to :delete_all, which I don't want, because I'd like to use the version table to potentially
    # resurrect deleted records as well.
    # TODO: Should think about looking at columns specified as unique, so if someone manually recreates a
    # unique record, then its version history will connect with the old one (and get the same primary key?)
    self.version_association_options  = {
                                                :class_name  => "#{self.to_s}::#{versioned_class_name}",
                                                :foreign_key => versioned_foreign_key
    }.merge(options[:association_options] || {})

    # This repeats the above for the update class
    self.version_update_association_options  = {
                                                :class_name  => "#{self.to_s}::#{versioned_update_class_name}",
                                                :foreign_key => versioned_foreign_key
    }.merge(options[:association_options] || {})

    # This allows you to supply a lambda or Proc etc. that I can call to get a user id
    self.version_updated_by = options[:version_updated_by] || nil

    if block_given?
      extension_module_name = "#{versioned_class_name}Extension"
      silence_warnings do
        self.const_set(extension_module_name, Module.new(&extension))
      end

      options[:extend] = self.const_get(extension_module_name)
    end

    unless options[:if_changed].nil?
      self.track_altered_attributes = true
      options[:if_changed] = [options[:if_changed]] unless options[:if_changed].is_a?(Array)
      self.version_if_changed = options[:if_changed].map(&:to_s)
    end

    include options[:extend] if options[:extend].is_a?(Module)

    include Behaviors

    #
    # Create the dynamic versioned model
    #
    # AAV defines some methods in a class_eval ... I do it with an extend below
    # so that I don't repeat it for the VersionUpdate class.
    # TODO: Eliminate more redundancy here.
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
    versioned_class.set_sequence_name version_sequence_name if version_sequence_name

    versioned_class.send :include, TracksVersions::InstanceMethodsForVersionClasses
    versioned_class.send :extend, TracksVersions::ClassMethodsForVersionClasses

    # Create the update model ... the main difference is that it gets its own primary key,
    # so that we can update individual versions with their version_to time.
    const_set(versioned_update_class_name, Class.new(ActiveRecord::Base))

    versioned_update_class.cattr_accessor :original_class
    versioned_update_class.original_class = self
    versioned_update_class.set_table_name versioned_table_name
    versioned_update_class.belongs_to self.to_s.demodulize.underscore.to_sym, {
      :class_name  => "::#{self.to_s}",
      :foreign_key => versioned_foreign_key
    }
    versioned_update_class.send :include, options[:extend] if options[:extend].is_a?(Module)
    versioned_update_class.set_sequence_name version_sequence_name if version_sequence_name

    versioned_update_class.send :include, TracksVersions::InstanceMethodsForVersionClasses
    versioned_update_class.send :extend, TracksVersions::ClassMethodsForVersionClasses
  end

  module ClassMethodsForVersionClasses
    def reloadable?
      false
    end

    # The logic of the next couple of methods are necessarily different from AAV

    # find first version before the given version
    def before(version)
      where(["#{original_class.versioned_foreign_key} = ? and version_from < ?", version.send(original_class.versioned_foreign_key), version.version_from]).
          order('version_from DESC').
          first
    end

    # find first version after the given version.
    def after(version)
      where(["#{original_class.versioned_foreign_key} = ? and version_from > ?", version.send(original_class.versioned_foreign_key), version.version_from]).
          order('version_from ASC').
          first
    end

    # finds earliest version of this record
    def earliest
      order("version_from asc").first
    end

    # find latest version of this record
    def latest
      order("version_from desc").first
    end

    # This is how to find a particular version as of a date. If nothing is returned, then
    # it was deleted on that date (or not yet created).
    def as_of what_time
      where(["version_from <= ? AND (version_to IS NULL OR version_to > ?)", what_time, what_time]).first
    end
  end

  module InstanceMethodsForVersionClasses
    def previous
      self.class.before(self)
    end

    def next
      self.class.after(self)
    end

    # These are convenience methods to switch from a Version to a VersionUpdate instance,
    # or vice-versa.
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

  # These are methods added to the main model
  module Behaviors
    # This is a bit of Rails magic that does what you might expect with included, ClassMethods and InstanceMethods
    extend ActiveSupport::Concern

    included do
      has_many :versions, self.version_association_options

      # An extra relation
      has_many :versions_for_update, self.version_update_association_options

      # We don't need set_new_version, because we keep track of that in the versioned model itself
      # We add an after_destroy because we're keeping track of that.
      after_save     :save_version
      after_destroy  :record_deletion
      after_save     :clear_old_versions
    end

    module InstanceMethods
      # Saves a version of the model in the versioned table.  This is called in the after_save callback by default
      # This necessarily diverges a bit from AAV
      def save_version
        # AAV evaluates the condition in a before_save, but that isn't necessary for us
        if new_record? || save_version?
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

            if self.class.version_updated_by && rev.respond_to?(:updated_by_id)
              user = self.class.version_updated_by.call
              rev.updated_by_id = user.id if user
            end

            rev.version_from = time
            rev.save!
          end
          self.versions.reset
          self.versions_for_update.reset
        end
        true
      end

      # This is something that AAV does not do.
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

      # Clears old revisions if a limit is set with the :limit option in <tt>acts_as_versioned</tt>.
      # Override this method to set your own criteria for clearing old versions.
      def clear_old_versions
=begin
TODO: Implement this? Could do it in terms of age instead. If not, would need to rewrite, since I don't count versions naturally.
        return if self.class.max_version_limit == 0
        excess_baggage = send(self.class.version_column).to_i - self.class.max_version_limit
        if excess_baggage > 0
          self.class.versioned_class.delete_all ["#{self.class.version_column} <= ? and #{self.class.versioned_foreign_key} = ?", excess_baggage, id]
        end
=end
        true
      end

      # Reverts a model to a given version.  Takes either a date or an instance of the versioned model
      # Note that this does not yet deal with associations at all ... Different from AAV, since we don't
      # use version numbers.
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
        # AAV uses save_without_revision here ... that doesn't make sense in my scheme, since I need to
        # mark the revision ...
        revert_to(version) ? save : false
      end

      # Temporarily turns off Optimistic Locking while saving.
      def save_without_revision
        save_without_revision!
        true
      rescue
        false
      end

      def save_without_revision!
        without_locking do
          without_revision do
            save!
          end
        end
      end

      def altered?
        track_altered_attributes ? (version_if_changed - changed).length < version_if_changed.length : changed?
      end

      # Clones a model.  Used when saving a new version or reverting a model's version.
      def clone_versioned_model(orig_model, new_model)
        self.class.versioned_columns.each do |col|
          new_model.send("#{col.name}=", orig_model.send(col.name)) if orig_model.has_attribute?(col.name)
        end

        # Need to check for both kinds of Version class.
        if orig_model.is_a?(self.class.versioned_class) || orig_model.is_a?(self.class.versioned_update_class)
          new_model[new_model.class.inheritance_column] = orig_model[self.class.versioned_inheritance_column]
        elsif new_model.is_a?(self.class.versioned_class) || new_model.is_a?(self.class.versioned_update_class)
          new_model[self.class.versioned_inheritance_column] = orig_model[orig_model.class.inheritance_column]
        end
      end

      # Checks whether a new version shall be saved or not.  Calls <tt>version_condition_met?</tt> and <tt>changed?</tt>.
      def save_version?
        version_condition_met? && altered?
      end

      # Checks condition set in the :if option to check whether a revision should be created or not.  Override this for
      # custom version condition checking.
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

      # Executes the block with the versioning callbacks disabled.
      #
      #   @foo.without_revision do
      #     @foo.save
      #   end
      #
      def without_revision(&block)
        self.class.without_revision(&block)
      end

      # Turns off optimistic locking for the duration of the block
      #
      #   @foo.without_locking do
      #     @foo.save
      #   end
      #
      def without_locking(&block)
        self.class.without_locking(&block)
      end

      def empty_callback()
      end
    end

    module ClassMethods
      # Returns an array of columns that are versioned.  See non_versioned_columns
      def versioned_columns
        @versioned_columns ||= columns.select { |c| !non_versioned_columns.include?(c.name) }
      end

      # Returns an instance of the dynamic versioned model
      def versioned_class
        const_get versioned_class_name
      end

      # Returns an instance of the versioned model for update
      def versioned_update_class
        const_get versioned_update_class_name
      end

      # Rake migration task to create the versioned table
      def create_versioned_table(create_table_options = {})
        return if connection.table_exists?(versioned_table_name)

        # Our structure is a little different from AAV
        self.connection.create_table(versioned_table_name, create_table_options) do |t|
          t.column versioned_foreign_key, :integer
          t.column :version_from, :datetime
          t.column :version_to, :datetime
        end

        self.versioned_columns.each do |col|
          self.connection.add_column versioned_table_name, col.name, col.type,
                                      :limit     => col.limit,
                                      :default   => col.default,
                                      :scale     => col.scale,
                                      :precision => col.precision
        end

        if type_col = self.columns_hash[inheritance_column]
          self.connection.add_column versioned_table_name, versioned_inheritance_column, type_col.type,
                                      :limit     => type_col.limit,
                                      :default   => type_col.default,
                                      :scale     => type_col.scale,
                                      :precision => type_col.precision
        end

        # We index a few more things compared with AAV
        [versioned_foreign_key, :version_from, :version_to].each do |col|
          self.connection.add_index versioned_table_name, col
        end
      end

      # Rake migration task to drop the versioned table
      def drop_versioned_table
        self.connection.drop_table versioned_table_name
      end

      # Executes the block with the versioning callbacks disabled.
      #
      #   Foo.without_revision do
      #     @foo.save
      #   end
      #
      def without_revision(&block)
        class_eval do
          CALLBACKS.each do |attr_name|
            alias_method "orig_#{attr_name}".to_sym, attr_name
            alias_method attr_name, :empty_callback
          end
        end
        block.call
      ensure
        class_eval do
          CALLBACKS.each do |attr_name|
            alias_method attr_name, "orig_#{attr_name}".to_sym
          end
        end
      end

      # Turns off optimistic locking for the duration of the block
      #
      #   Foo.without_locking do
      #     @foo.save
      #   end
      #
      def without_locking(&block)
        current = ActiveRecord::Base.lock_optimistically
        ActiveRecord::Base.lock_optimistically = false if current
        begin
          block.call
        ensure
          ActiveRecord::Base.lock_optimistically = true if current
        end
      end
    end
  end
end

ActiveRecord::Base.extend TracksVersions
