class Audit < ActiveRecord::Base
  
  include FieldsAudited::Audit
  
end