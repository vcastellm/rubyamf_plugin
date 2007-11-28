class ActiveRecord::Base
  
  #This holds the original incoming Value Object from deserialization time, as when an incoming VO with an 'id' property
  #on it is found, it is 'found' (Model.find(id)) in the DB (instead of Model.new(hash)). So right before the params hash
  #is updated for the rails request, I slip in this original object so you can do an "update_attributes(params[:model])"
  #and the correct 'update' values will be used.
  attr_accessor :original_vo_from_deserialization
  
  def as_single!
    SDTOUT.puts "ActiveRecord::Base#as_single! is no longer needed, all single active records return as an object. This warning will be taken out in 1.4, please update your controller"
    self
  end
  def single!
    SDTOUT.puts "ActiveRecord::Base#as_single! is no longer needed, all single active records return as an object. This warning will be taken out in 1.4, please update your controller"
    self
  end
end