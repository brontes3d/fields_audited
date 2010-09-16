$:.unshift "#{File.dirname(__FILE__)}/lib"
require 'fields_audited'
require 'fields_audited/as_belonging_to'

ActiveRecord::Base.send :include, FieldsAudited::Acts::Audited
ActiveRecord::Base.send :include, FieldsAudited::Acts::AsBelongingTo

# Audit.class_eval do
#   include FieldsAudited::Audit
# end

if defined?(FieldDefs)
  FieldDefs.global_defaults do
    
    default_for_proc_type(:old_version) do |field_defs|
      Proc.new do |thing|
        FieldsAudited.make_dup_with_changes_reverted(thing)
      end
    end

    default_for_proc_type(:changes) do |field_defs|
      Proc.new do |thing|
        thing.changes[field_defs.field_name.to_s]
      end
    end

    default_for_proc_type(:changes_display_proc) do |field_defs|
      Proc.new do |before, after|
        dp = field_defs.display_proc
        [field_defs.display_proc.call(before), field_defs.display_proc.call(after)]
      end
    end

    default_for_proc_type(:read_changes_for_fields_audited_as_belonging_to) do |field_defs|
      Proc.new do |my_obj, my_obscurely_related_obj|
        raise NotImplementedError, "how_to_record_display_changes not implemented for #{field_defs.field_name}"
      end
    end
    
    default_for_mixed_type(:changes_determined_by_has_one) do |field_defs|
      [field_defs.field_name.to_s,
      Proc.new do |changes|
        # changes[field_defs.field_name.to_s]
        raise NotImplementedError, "changes_determined_by_has_one not implemented for #{field_defs.field_name}"
      end]
    end

    default_for_mixed_type(:changes_determined_by_has_many) do |field_defs|
      [field_defs.field_name.to_s,
      Proc.new do |changes|
        # changes[field_defs.field_name.to_s]
        raise NotImplementedError, "changes_determined_by_has_many not implemented for #{field_defs.field_name}"
      end]
    end

    default_for_mixed_type(:changes_determined_by_belongs_to) do |field_defs|
      [field_defs.field_name.to_s,
      Proc.new do |changes|
        # changes[field_defs.field_name.to_s]
        raise NotImplementedError, "changes_determined_by_belongs_to not implemented for #{field_defs.field_name}"
      end]
    end
    
    # default_for_proc_type(:changes_proc) do |field_defs|
    #   Proc.new do |thing|
    #     thing.changes[field_defs.field_name.to_s] || []
    #   end
    # end
    # 
    # default_for_proc_type(:assoc_change_proc) do |field_defs|
    #   Proc.new do |thing, assoc_thing|
    #     puts "default assoc_change_proc #{thing} #{assoc_thing} : " + assoc_thing.changes.inspect
    #     assoc_thing.changed?
    #   end
    # end
    
  end
end
