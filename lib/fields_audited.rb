module FieldsAudited
  
  module Audit
    
    mattr_accessor :audit_klass
    
    def self.while_auditing(&block)
      if audit_klass && audit_klass.respond_to?(:while_auditing)
        audit_klass.while_auditing(&block)
      else
        yield
      end
    end
    
    def self.included(base)
      self.audit_klass = base
      base.class_eval do
        include ActsAsAudited::Audit
        
        serialize :display_changes

        belongs_to :auditable_belongs_to, :polymorphic => true
        
        def version
          self.id
        end

        protected

        def set_version_number
          #do nothing
        end
      end
    end
    
  end
  
  
  def self.has_deep_changes?(on_thing)
    if on_thing.respond_to?(:changed?)
      return on_thing.changed?
    elsif(on_thing.is_a?(Array))
      on_thing.each do |t|
        return true if(has_deep_changes?(t))
      end
    end
    return false
  end
  
  def self.make_dup_with_changes_reverted(from_thing) 
    to_return = nil
    if from_thing.respond_to?(:changes)
      to_return = from_thing.clone
      from_thing.changes.each do |key, change|
        # to_return.send("#{key}=", change[0])
        to_return.write_attribute(key, change[0])
      end
    elsif(from_thing.is_a?(Array))
      to_return = from_thing.collect{ |t| make_dup_with_changes_reverted(t)}
    end
    to_return
  end
  
  module Acts # :nodoc:
    module Audited

      def self.included(base) # :nodoc:
        base.extend ClassMethods
      end
            

      module ClassMethods
        
                
        # == Configuration options
        #
        # * <tt>except</tt> - Excludes fields from being saved in the audit log.
        #   By default, acts_as_audited will audit all but these fields: 
        # 
        #     [self.primary_key, inheritance_column, 'lock_version', 'created_at', 'updated_at']
        #
        #   You can add to those by passing one or an array of fields to skip.
        #
        #     class User < ActiveRecord::Base
        #       acts_as_audited :except => :password
        #     end
        # 
        def fields_audited(options = {})          
          self.acts_as_audited(options)
          
          return unless options[:fields]
          # don't allow multiple calls
          return if self.included_modules.include?(FieldsAudited::Acts::Audited::InstanceMethods)
          
          include FieldsAudited::Acts::Audited::InstanceMethods 
          
          class_inheritable_reader :audited_field_defs
          # class_inheritable_reader :audited_child_assoc_field_defs
          
          fields = {}
          (options[:fields] ||[]).each do |fd|
            fields[fd.field_name] = fd
          end
          write_inheritable_attribute :audited_field_defs, fields
          
          # write_inheritable_attribute :audited_child_assoc_field_defs, {}
          
          self.class_eval do
            cattr_accessor :audited_child_assoc_field_defs
            
            has_many :audits_and_child_audits, :as => :auditable_belongs_to, 
              :class_name => "Audit", :order => 'audits.id desc'
            
            has_many :child_audits, :as => :auditable_belongs_to, 
              :class_name => "Audit", :order => 'audits.id desc',
              :conditions => "audits.auditable_belongs_to_type <> audits.auditable_type"
            
            has_many :audits, :as => :auditable, :order => 'audits.id desc'
            
          end
          
          self.audited_child_assoc_field_defs ||= {}
          
          # assoc_fields = {}
          # (options[:assoc_fields] ||[]).each do |fd|
          #   assoc_fields[fd.field_name] = fd
          #   # puts "assoc field: " +  fd.inspect
          #   # reflection = self.reflect_on_association(fd.field_name)
          #   # puts "Asking #{self} to reflect " + reflection.inspect
          # 
          #   # if reflection && (reflection.macro == :has_many)
          #   #   assoc = self.name.singularize.underscore
          #   #   matching_belongs_to = reflection.klass.reflect_on_association(assoc.to_sym)
          #   #   if matching_belongs_to && (matching_belongs_to.macro == :belongs_to)                
          #   #     reflection_name = reflection.name
          #   #     belongs_to_name = matching_belongs_to.name
          #       
          #       reflection_name = fd.field_name
          #       klass = fd.field_name.to_s.singularize.camelize.constantize
          #       belongs_to_name = self.name.singularize.underscore
          #       
          #         before_save_named = "assoc_saveback_#{fd.field_name}_#{reflection_name}_#{belongs_to_name}"
          #         klass.class_eval do
          #           eval %Q{
          #             before_save :#{before_save_named}
          #     
          #             def #{before_save_named}
          #               if self.changed?
          #                 self.#{belongs_to_name}.write_audit(:update, nil, :#{reflection_name} => self)
          #               end
          #             end
          #           }
          #         end            
          #         
          #   #     else
          #   #       raise ArgumentError, "No matching :belongs_to association on #{reflection.klass} found for #{assoc}"                  
          #   #     end
          #   # else
          #   #   raise ArgumentError, "No :has_many association on #{self} found for #{fd.field_name}"
          #   # end
          #   
          # end
          # write_inheritable_attribute :audited_assoc_field_defs, assoc_fields
          
        end

      end    

      module InstanceMethods
        
        def audit_changed?(attr_name = nil)
          #Can;t make this change because audit_changed? is often called after_save in which case changes will be emptied out

          # attr_name ? self.changes[attr_name.to_s] : !self.changes.empty?
          attr_name ? excepted_changes[attr_name.to_s] : (!excepted_changes.empty? || !display_changes.empty?)
          # attr_name ? audit_changed_attributes.include?(attr_name.to_s) : !audit_changed_attributes.empty?
        end
        
        def field_changes(action = nil)
          field_changes = {}

          self.audited_field_defs.each do |key, fd|               
            # puts "checking if #{key} changed on action #{action}"
            record_field_change(field_changes, key, fd, nil, action)
            
            # if fd.changes.call(self)
            #   old_version = fd.old_version.call(self)
            #   field_changes[key] = [
            #     fd.reader_proc.call(old_version), 
            #     fd.reader_proc.call(self)]
            # end
            
            # if change = fd.changes_proc.call(self)
            #   unless change.empty?
            #     field_changes[key] = change
            #   end
            # end
            # check_for_field_change(field_changes, key)
            # fchanges = fd.changes_proc.call(self)
            # unless fchanges.empty?
            #   record_field_change(field_changes, fd.field_name, fchanges)
            # end
          end

          # self.audited_assoc_field_defs.each do |key, fd|
          #   self.send("#{key}").each do |assoc_thing|
          #     record_assoc_field_change(field_changes, key, assoc_thing)
          #   end
          # end

          field_changes
        end
        
        def record_field_change(changes_array, key, fd, via_assoc = nil, action = nil, changed_thing = nil)
          # Rails.logger.debug { "testing if there are changes to #{key} on #{self.inspect}" }
          
          if via_assoc
            # Rails.logger.debug { "supposed to act according to assoc: " + via_assoc.inspect }
            
            if :direct == via_assoc
              
              if display_changes = fd.read_changes_for_fields_audited_as_belonging_to.call(self, changed_thing)
                unless display_changes.empty?
                  if display_changes[0] != display_changes[1]
                    changes_array[key] = display_changes
                  end
                end
              end
              
            elsif via_assoc.macro == :has_one
              assoc_name = fd.changes_determined_by_has_one(:arg)
              
              #TODO: should we somehow assert that assoc_name == via_assoc.name ??
              
              assoc_thing = self.send(assoc_name)
              # assoc_thing = self.send(via_assoc.name)
              
              if assoc_thing && fd.changes_determined_by_has_one.call(assoc_thing.changes)
                old_version = fd.old_version.call(self)
                old_version.send("#{assoc_name}=", FieldsAudited.make_dup_with_changes_reverted(assoc_thing))                
                # puts "old_version: #{old_version}"                
                changes_array[key] = [
                  fd.reader_proc.call(old_version), 
                  fd.reader_proc.call(self)]                
              end
            elsif via_assoc.macro == :has_many
              
              assoc_name = fd.changes_determined_by_has_many(:arg)
              assoc_things = self.send(assoc_name)
              
              changes = false
              assoc_things.collect do |assoc_thing|
                changes ||= fd.changes_determined_by_has_many.call(assoc_thing.changes)
              end
              if changes
                old_version = fd.old_version.call(self)
                old_version.send("#{assoc_name}=", assoc_things.collect do |thing|
                    FieldsAudited.make_dup_with_changes_reverted(thing)
                  end)
                changes_array[key] = [
                  fd.reader_proc.call(old_version), 
                  fd.reader_proc.call(self)]
              end
            elsif via_assoc.macro == :belongs_to
              
              assoc_name = fd.changes_determined_by_belongs_to(:arg)
              # Rails.logger.debug { "assoc_name = #{assoc_name.inspect}" }
              assoc_thing = self.send(assoc_name)
              # Rails.logger.debug { "assoc_thing = #{assoc_thing.inspect}" }
              
              if fd.changes_determined_by_belongs_to.call(assoc_thing.changes)
                old_version = fd.old_version.call(self)
                old_version.send("#{assoc_name}=", FieldsAudited.make_dup_with_changes_reverted(assoc_thing))                
                # puts "old_version: #{old_version}"                
                changes_array[key] = [
                  fd.reader_proc.call(old_version), 
                  fd.reader_proc.call(self)]                
              end              
            end
          elsif action == :create
            changes_array[key] = ["", fd.reader_proc.call(self)]
          elsif action == :destroy
            changes_array[key] = [fd.reader_proc.call(self), ""]
          elsif fd.changes.call(self)
            old_version = fd.old_version.call(self)
            # puts "old_version: #{old_version}"
            changes_array[key] = [
              fd.reader_proc.call(old_version), 
              fd.reader_proc.call(self)]
          end
        end

        # def check_for_field_change(changes_array, key)
        #   fd = self.audited_field_defs[key]
        #   if change = fd.changes_proc.call(self)
        #     unless change.empty?
        #       changes_array[key] = change
        #     end
        #   end
        # end
        
        # def record_field_change(changes_array, key, change)
        #   fd = self.audited_field_defs[key]
        #   if change = fd.changes_proc.call(self)
        #     changes_array[key] = change
        #   end
        # end
        
        # def record_assoc_field_change(changes_array, key, value)
        #   fd = self.audited_assoc_field_defs[key]
        #   if change = fd.changes_proc.call(self, value)
        #     # RAILS_DEFAULT_LOGGER.debug("Assoc change: " + change.inspect)
        #     # puts "Assoc change: " + change.inspect
        #         changes_array[key] ||= []
        #         changes_array[key] << change
        #   end
        # end
                
        def display_changes(for_field_changes = field_changes)
          display_changes = {}
          for_field_changes.each do |key, changes|
            # puts "for #{key} handle changes: " + changes.inspect
            if field_def = (self.audited_field_defs[key] || self.audited_child_assoc_field_defs[key])

              # before = field_def.display_proc.call(changes[0])
              # after = field_def.display_proc.call(changes[1])
              # display_changes[field_def.human_name] = [before, after]

              # before = field_def.display_proc.call(changes[0])
              # after = field_def.display_proc.call(changes[1])
              # display_changes[field_def.human_name] = ["hi", "hi"]
              
              unless changes[0].blank? && changes[1].blank?
                display_changes[field_def.human_name] = field_def.changes_display_proc.call(changes[0], changes[1])
              end

            # elsif field_def = self.audited_assoc_field_defs[key]
            #     dchanges = [[], []]
            #     changes.each do |change|
            #       before = field_def.display_proc.call([change[0]])
            #       after = field_def.display_proc.call([change[1]])
            #       dchanges[0] << before
            #       dchanges[1] << after
            #     end
            #     display_changes[field_def.human_name] = dchanges
            else
              raise ArgumentError, "#{self} No field def for #{key} found in: #{self.audited_field_defs.keys.inspect} "+
                "or in: #{self.audited_child_assoc_field_defs.keys.inspect}"
            end
          end
          display_changes
        end
        
        def record_audit_note(display_changes)
          created_audit = self.audits.create :audit_changes => excepted_changes, 
                             :display_changes => display_changes, 
                             :action => 'update', 
                             :auditable_belongs_to => self
        end
        
        def audit_create
          if self.class.auditing_enabled          
            FieldsAudited::Audit.while_auditing do
              write_audit(:create)
            end
          end
          true
        end

        def audit_update
          if self.class.auditing_enabled
            FieldsAudited::Audit.while_auditing do
              write_audit(:update) if audit_changed?
            end
          end
          true
        end

        def audit_destroy
          if self.class.auditing_enabled
            FieldsAudited::Audit.while_auditing do
              write_audit(:destroy)
            end
          end
          true
        end   
        
        def write_audit(action = :update, user = nil, extra_assoc_changes = nil)
          f_changes = self.field_changes(action)
          # puts "f_changes: " + f_changes.inspect
          if(extra_assoc_changes)
            f_changes.merge!(extra_assoc_changes)
          #   extra_assoc_changes.each do |key, changed_obj|
          #     record_assoc_field_change(f_changes, key, changed_obj)
          #   end
          end
          if auditable_belongs_to = (self.respond_to?(:audit_parent)) ? self.audit_parent : self
            display_changes = self.display_changes(f_changes)
            unless display_changes.empty?
              created_audit = self.audits.create :audit_changes => excepted_changes, 
                                 :display_changes => display_changes, 
                                 :action => action.to_s, :user => user, 
                                 :auditable_belongs_to => auditable_belongs_to
            end
          end
          # puts "\ncreated audit: " + created_audit.inspect + " \n from changes: " + self.changes.inspect +
          #   "\n\n extra_assoc_changes: " + extra_assoc_changes.inspect
          # 
          # begin
          #   raise "test"
          # rescue => e
          #   puts "trace:"
          #   e.backtrace.each do |line|
          #     puts "\t\t#{line}"
          #   end
          # end
        end
                
      end
      
    end
  end
end