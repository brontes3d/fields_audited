class User < ActiveRecord::Base
  def self.field_defs
    @@field_defs ||= FieldDefs.new(User) do
            
      field(:name).display_proc do |val|
        "me llamo #{val}"
      end
      
      #TODO: write in the rdoc an explanation of the changes proc
      #The changes proc is used to determine if there are changes to a field
      #in the default case, we just check for changes by the field name
      #but in this case there is not 'pig_latin_name' column
      #so we have to instrcut fields_audited
      #to look for changes to the name column
      #to determine if pig_latin_name_changed
      field(:pig_latin_name).reader_proc do |user|
        n = user.name.to_s
        (n[1,n.size].to_s + n[0,1].to_s + "ay").capitalize
      end.changes do |user|
        user.changes['name']
      end
      
      field(:digits).reader_proc do |user|
        running_total = 0
        user.appendages.collect do |app|
          (app.phalangeal_formula || []).collect do |carpals|
            running_total += 1 if carpals > 0
          end
        end
        running_total
      end.changes_determined_by_has_many('appendages') do |changes|
        changes['phalangeal_formula']
      end      
            
      field(:tongue_color).reader_proc do |user|
        user.tongue.color
      end.changes_determined_by_has_one('tongue') do |changes|
        changes['color']
      end
      
      field(:seat_state).reader_proc do |user|
        user.toilet_seat.state
      end.changes_determined_by_belongs_to('toilet_seat') do |changes|
        changes['state']
      end
      
    end
  end

  has_many :appendages
  has_one :tongue
  belongs_to :toilet_seat
    
  fields_audited :except => :password, 
                  :fields => User.field_defs.fields_called([:name, :pig_latin_name])
    
  def self.current_user
  end
  
  def lose_a_digit!
    appendage = self.appendages.rand
    digit = ((rand*5).to_i)
    new_phalangeal_formula = appendage.phalangeal_formula.dup
    # new_phalangeal_formula[digit] -= 1
    new_phalangeal_formula[digit] = 0
    appendage.phalangeal_formula = new_phalangeal_formula
    appendage.save!
    
    # puts "lost a digit, field changes: " + self.field_changes.inspect
  end
  
  def eat_a_lolipop!
    tongue.color = "Blue"
    tongue.save!
  end
  
end

class Tongue < ActiveRecord::Base
  belongs_to :user
  
  fields_audited_as_belonging_to :user,
                                 :which_has_one => :tongue,
                                 :assoc_fields => User.field_defs.fields_called([:tongue_color])
                                 
end

class Appendage < ActiveRecord::Base
  def self.field_defs
    @@field_defs ||= FieldDefs.new(Appendage) do
      field(:phalangeal_formula)
      field(:appentage_type).reader_proc{ "arm" }
    end
  end

  belongs_to :user
  belongs_to :center_joint
  
  fields_audited_as_belonging_to :user, 
                                 :which_has_many => :appendages,
                                 :fields => field_defs.all_fields,
                                 :assoc_fields => User.field_defs.fields_called([:digits])
  
  # , :fields => Appendage.field_defs.fields_called([:phalangeal_formula])
  
  serialize :phalangeal_formula
  
end

class CenterJoint < ActiveRecord::Base
  
  has_one :appendage
  
  def bend!
    self.appendage.user.record_audit_note({self.name => [self.state, "bent"]})
    self.state = "bent"
    self.save!
  end
  
end

class ToiletSeat < ActiveRecord::Base
  has_one :user
  
  fields_audited_as_belonging_to :user, 
                                 :which_belongs_to => :toilet_seat,
                                 :assoc_fields => User.field_defs.fields_called([:seat_state])
  
end
