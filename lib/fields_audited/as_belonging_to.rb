module FieldsAudited::Acts::AsBelongingTo
  
  def self.included(base) # :nodoc:
    base.extend ClassMethods
  end

  module ClassMethods
    
    def fields_audited_as_belonging_to(assoc_to_parent, options = {})
      return if self.included_modules.include?(FieldsAudited::Acts::AsBelongingTo::InstanceMethods)
      
      include FieldsAudited::Acts::AsBelongingTo::InstanceMethods          
      
      fields_audited(options)
      
      class_inheritable_reader :audited_assoc_field_defs
      class_inheritable_reader :audit_assoc_to_parent

      if assoc_to_parent.is_a?(Symbol)
        to_parent_reflection = self.reflect_on_association(assoc_to_parent)
        unless to_parent_reflection
          raise ArgumentError, "association: '#{assoc_to_parent}' not found on #{self}"
        end
        to_parent_klass = to_parent_reflection.klass
      else
        to_parent_klass = assoc_to_parent
      end
      unless to_parent_klass.included_modules.include?(FieldsAudited::Acts::Audited::InstanceMethods)
        raise ArgumentError, "class #{to_parent_klass} from reflection "+
                              "#{assoc_to_parent} expected to have 'fields_audited'"
      end
      
      assoc_fields = {}
      (options[:assoc_fields] ||[]).each do |fd|
        assoc_fields[fd.field_name] = fd
        to_parent_klass.audited_child_assoc_field_defs[fd.field_name] = fd
        # puts "fd: " + fd.inspect
        # puts "to_parent_reflection.klass: " + 
        #     to_parent_reflection.klass.name.inspect
        # puts "to_parent_reflection.klass.audited_child_assoc_field_defs: " + 
        #     to_parent_reflection.klass.audited_child_assoc_field_defs.keys.inspect
      end
      
      write_inheritable_attribute :audited_assoc_field_defs, assoc_fields
      write_inheritable_attribute :audit_assoc_to_parent, assoc_to_parent
      
      if which_has_many = options[:which_has_many]
        class_inheritable_reader :my_audit_which_has_many
        write_inheritable_attribute :my_audit_which_has_many, which_has_many
      elsif which_has_one = options[:which_has_one]
        class_inheritable_reader :my_audit_which_has_one
        write_inheritable_attribute :my_audit_which_has_one, which_has_one
      elsif which_belongs_to = options[:which_belongs_to]
        class_inheritable_reader :my_audit_which_belongs_to
        write_inheritable_attribute :my_audit_which_belongs_to, which_belongs_to
      elsif each_of_which_has_a = options[:each_of_which_has_a]
        class_inheritable_reader :my_audit_each_of_which_has_a
        write_inheritable_attribute :my_audit_each_of_which_has_a, each_of_which_has_a
      elsif fetched_via = options[:fetched_via]
        class_inheritable_reader :my_audit_fetched_via
        write_inheritable_attribute :my_audit_fetched_via, fetched_via
      else
        raise ArgumentError, "one of (:which_has_one, :which_has_many, :which_belongs_to) options must be provided!"
      end
      
      class_eval do        
        after_create :audit_assoc_create
        after_update :audit_assoc_update
        after_destroy :audit_assoc_destroy
      end
    end
    
  end
  
  module InstanceMethods     
    def audit_assoc_create
      if self.class.auditing_enabled
        write_assoc_audit(:create)
      end
      true
    end

    def audit_assoc_update
      if self.class.auditing_enabled
        write_assoc_audit(:update)
      end
      true
    end

    def audit_assoc_destroy
      if self.class.auditing_enabled
        write_assoc_audit(:destroy)
      end
      true
    end
    
    def audit_parent
      if reflection = self.class.reflect_on_association(audit_assoc_to_parent)
        self.send(reflection.name)
      elsif my_audit_fetched_via
        my_audit_fetched_via.call(self)
      else
        raise ArgumentError, "can't follow association to audit to #{audit_assoc_to_parent} from #{self}"
      end
    end
    
    def reflection_of_audit_has_one
      audit_parent.class.reflect_on_association(my_audit_which_has_one)
    end
    
    def assign_audit_has_one(arg)
      if association = audit_parent.send("#{reflection_of_audit_has_one.name}")
        association.target = arg
      end
    end
    
    def reflection_of_audit_belongs_to
      audit_parent.class.reflect_on_association(my_audit_which_belongs_to)
    end
        
    def assign_audit_belongs_to(arg)
      if association = audit_parent.send("#{reflection_of_audit_belongs_to.name}")
        association.target = arg
      end      
    end
    
    def reflection_of_audit_has_many
      audit_parent.class.reflect_on_association(my_audit_which_has_many)    
    end
    
    def audit_has_many
      audit_parent.send(reflection_of_audit_has_many.name)
    end
    
    def auditing_a_has_many?
      self.respond_to?(:my_audit_which_has_many)
    end

    def auditing_a_has_one?
      self.respond_to?(:my_audit_which_has_one)
    end

    def auditing_a_belongs_to?
      self.respond_to?(:my_audit_which_belongs_to)
    end
    
    def auditing_an_each_of_which_has_a?
      self.respond_to?(:my_audit_each_of_which_has_a)      
    end
    
    def write_assoc_audit(action = :update, user = nil)
      # puts "running write audit for as_belonging_to"
      extra_changes = {}
      self.audited_assoc_field_defs.each do |key, fd|
        
        # puts "supposed to write audit for change on assoc: #{key} " + self.changes.inspect + " -#{self.new_record?.inspect}-"
        
        # begin
        #   raise "test"
        # rescue => e
        #   puts "supposed to write audit trace:"
        #   e.backtrace.each do |line|
        #     puts "\t\t#{line}"
        #   end
        # end
        
        if self.changed? && audit_parent
          # puts "self changed #{self.changes.inspect}"
          # puts "audit_parent: " + audit_parent.inspect
          
          if auditing_a_has_many?
            # puts "audit_has_many: " + audit_has_many.inspect
            if self_is_at = audit_has_many.index(self) || audit_has_many.reload.index(self)
              # puts "self_is_at " + self_is_at.inspect
              audit_has_many[self_is_at] = self
            
              audit_parent.record_field_change(extra_changes, key, fd, reflection_of_audit_has_many)
            
              # unless audit_belongs_to.audited_assoc_field_defs[key]
              #   audit_belongs_to.audited_assoc_field_defs[key] = fd
              # end
            
            end
          elsif auditing_a_has_one?
            # puts "Assiging audit has one: " + self.object_id.inspect
            assign_audit_has_one(self)
            audit_parent.record_field_change(extra_changes, key, fd, reflection_of_audit_has_one)
          elsif auditing_a_belongs_to?
            # puts "it's a belongs to"
            assign_audit_belongs_to(self)
            audit_parent.record_field_change(extra_changes, key, fd, reflection_of_audit_belongs_to)            
          elsif auditing_an_each_of_which_has_a?
            audit_parent.each do |ap|
              ap.record_field_change(extra_changes, key, fd, :direct, nil, self)
            end
          end
        end
        
      end
      unless extra_changes.empty?
        if !audit_parent.respond_to?(:write_audit) && audit_parent.respond_to?(:each)
          audit_parent.each do |ap|
            ap.write_audit(:update, nil, extra_changes)
          end
        else
          audit_parent.write_audit(:update, nil, extra_changes)
        end
      end
    end
  end
  
end