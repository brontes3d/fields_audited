require File.join(File.dirname(__FILE__), 'test_helper')

class FieldsAuditedTest < Test::Unit::TestCase
  
  def setup
    Audit.destroy_all
  end
  
  
  def test_record_audit_note
    u = create_user
    app = create_appendage
    u.appendages = [app]
    app.center_joint = create_joint(:name => 'Elbow', :state => "straight")
    app.save!
    u.save!
    
    app.center_joint.bend!
    
    u.reload
    latest_audit = u.audits.first    
    
    assert_equal(latest_audit.display_changes["Elbow"], ["straight", "bent"],
      "Display changes should have recorded elbow change, but got: \n" + latest_audit.inspect)    
  end
  
  def test_toungue_color_changed
    u = create_user
    u.tongue = create_tongue
    u.save!
    u = User.find(u.id)
  
    assert !u.audit_changed?
    
    u.eat_a_lolipop!
    
    assert_equal(2, u.audits.count, 
      "2 audit entries for User should have been created, 1 one for the user create, 1 for the change to Tongue Color")
    
    audits = u.audits.sort{ |a,b| a.id <=> b.id }
    
    first_audit = audits[0]
    assert(first_audit.audit_changes["name"], 
      "Changes recorded in the first audit should include changes to name, but was: \n" + first_audit.inspect)

    assert(first_audit.display_changes["Name"], 
      "Display changes recorded in the first audit should include changes to Name, but was: \n" + first_audit.inspect)
    
    second_audit = audits[1]
    assert(second_audit.audit_changes.empty?, 
      "Changes recorded in the second audit should be empty, but was: \n" + second_audit.inspect)

    assert(second_audit.display_changes["Tongue color"], 
      "Display changes recorded in the second audit should include changes to Tongue color, but was: \n" + second_audit.inspect)    
  end
  
  def test_appendages_changed
    u = create_user
    u.appendages = [create_appendage(:name => "Right Arm"), create_appendage(:name => "Left Arm")]
    u.save!
    u = User.find(u.id)
  
    assert !u.audit_changed?
    
    u.lose_a_digit!
    
    assert_equal(2, u.audits.count, 
      "2 audit entries for User should have been created, 1 one for the user create, 1 for the change to Digits")
    
    audits = u.audits.sort{ |a,b| a.id <=> b.id }
    
    first_audit = audits[0]
    assert(first_audit.audit_changes["name"], 
      "Changes recorded in the first audit should include changes to name, but was: \n" + first_audit.inspect)

    assert(first_audit.display_changes["Name"], 
      "Display changes recorded in the first audit should include changes to Name, but was: \n" + first_audit.inspect)

    second_audit = audits[1]
    assert(second_audit.audit_changes.empty?, 
      "Changes recorded in the second audit should be empty, but was: \n" + second_audit.inspect)

    assert(second_audit.display_changes["Digits"], 
      "Display changes recorded in the second audit should include changes to Digits, but was: \n" + second_audit.inspect)
  end
  
  def test_who_left_the_toilet_seat_up
    u = create_user
    u.toilet_seat = create_toilet_seat(:state => "Down")
    u.save!
    ts = ToiletSeat.find(u.toilet_seat.id)
    
    ts.state = "Up"
    ts.save!
    u.reload
    
    latest_user_audit = u.audits.first
    
    assert_equal(["Down", "Up"], latest_user_audit.display_changes["Seat state"],
      "Expected latest user audit to have Seat state change down to up, but found: #{latest_user_audit.inspect}")
  end
  
  # def test_digits_change_audited
  #   u = create_user
  #   u.appendages = [create_appendage(:user => u, :name => "Left Arm")]
  #   u.save!
  #   u = User.find(u.id)
  # 
  #   # assert_difference(Audit, :count){ u.lose_a_digit! }
  #   
  #   audit = Audit.find(u.audits.first.id)
  #   # puts "latest audit: " + audit.inspect
  # end

  def test_make_dup_with_changes_reverted
    u = create_user
    u.appendages = [create_appendage(:user => u, :name => "Left Arm")]
    u.save!
    u = User.find(u.id)

    u.lose_a_digit!

    assert_not_equal(u.appendages, FieldsAudited.make_dup_with_changes_reverted(u.appendages))
  end
  
  def test_name_change_audits_a_pig_latin_name_change
    u = create_user(:name => "Jacob")
    u.save!
    
    u.name = "Bob"
    u.save!    
    u.reload
    
    latest_audit = u.audits.first
    assert_equal(["Acobjay", "Obbay"], latest_audit.display_changes["Pig latin name"],
      "Expected to have recorded changes to Pig latin name, but found: #{latest_audit.inspect}")
  end

  def test_display_changes
    u = create_user
    u.appendages = [create_appendage(:user => u, :name => "Right Arm")]
    u.save!
    u = User.find(u.id)

    # puts u.field_changes.inspect

    assert !u.audit_changed?

    u.name = "Bob"
    u.lose_a_digit!

    assert u.audit_changed?

    # puts u.display_changes.inspect
    # assert something about the contents of u.display_changes    
    assert_equal("me llamo Bob", u.display_changes["Name"][1])

    assert u.audit_changed?
    assert_difference(Audit, :count){ u.save! }
  end
  
  def test_phalangeal_formula_changes_are_audited_on_appendage_as_belonging_to_user
    u = create_user
    u.appendages = [create_appendage(:user => u, :name => "Right Arm")]
    u.save!
    
    appendage = u.appendages[0]
    appendage.phalangeal_formula = [1,2,3,4,5]
    appendage.save!
    
    u.reload
    appendage.reload
    
    latest_appendage_audit = appendage.audits.first
    lastest_user_child_audit = u.child_audits.first
    
    assert_equal(latest_appendage_audit, lastest_user_child_audit)
    
    assert_equal([[2, 3, 3, 3, 3], [1, 2, 3, 4, 5]],
      latest_appendage_audit.audit_changes['phalangeal_formula'], 
        "expected #{latest_appendage_audit.inspect} to contain phalangeal_formula audit_changes")
    assert_equal(["23333", "12345"],
      latest_appendage_audit.display_changes['Phalangeal formula'], 
        "expected #{latest_appendage_audit.inspect} to contain Phalangeal formula display_changes")
        
    assert_equal(u.audits_and_child_audits.size, (u.child_audits + u.audits).size)
    
    combined_audits = (u.child_audits + u.audits).sort{ |a, b| b.version <=> a.version }
    
    assert_equal(u.audits_and_child_audits, combined_audits)
  end

  
  def test_appentage_type_changes_are_audited_on_appendage_as_belonging_to_user
    u = create_user
    u.appendages = [create_appendage(:user => u, :name => "Right Arm")]
    u.save!
    
    appendage = u.appendages[0]
    appendage.destroy
    
    creation_audit = u.child_audits.last
    
    # puts "creation_audit: " + creation_audit.inspect
    assert_equal("create", creation_audit.action)    
    assert_equal(["", "arm"], creation_audit.display_changes["Appentage type"])    
    
    destruction_audit = u.child_audits.first
    
    # puts "destruction_audit: " + destruction_audit.inspect
    assert_equal("destroy", destruction_audit.action)
    assert_equal(["arm", ""], destruction_audit.display_changes["Appentage type"])
  end

  # def test_update_to_appendages_stores_an_audit_for_user
  #   u = create_user
  #   u.appendages = [create_appendage(:user => u, :name => "Right Foot"), create_appendage(:user => u, :name => "Left Foot")]
  #   u.save!
  #   u = User.find(u.id)
  # 
  #   u.lose_a_digit!
  # 
  #   # puts (u.appendages[0].changed? || u.appendages[1].changed?).inspect
  #   assert_difference(Audit, :count){ u.appendages.each(&:save!) }
  # 
  # 
  #   audit = Audit.find(u.audits.first.id)
  #   # puts "audit: " + audit.inspect
  # end

  private

  def create_toilet_seat(attrs = {})
    ToiletSeat.create({:state => "Down"}.merge(attrs))
  end

  def create_joint(attrs = {})
    CenterJoint.create({:name => 'Elbow', :state => "bent"}.merge(attrs))
  end
  
  def create_appendage(attrs = {})
    Appendage.create({:name => 'Left Arm', :phalangeal_formula => [2,3,3,3,3]}.merge(attrs))
  end

  def create_tongue(attrs = {})
    Tongue.create({:color => 'Pink'}.merge(attrs))
  end

  def create_user(attrs = {})
    User.create({:name => 'Brandon', :username => 'brandon', :password => 'password'}.merge(attrs))
  end

  def create_versions(n = 2)
    returning User.create(:name => 'Foobar 1') do |u|
      (n - 1).times do |i|
        u.update_attribute :name, "Foobar #{i + 2}"
      end
      u.reload
    end

  end

end
