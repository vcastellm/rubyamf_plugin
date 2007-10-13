class Object
  attr_accessor :_explicitType
  attr_accessor :rmembers
  attr_accessor :id
    
  def get_members
    if self.rmembers != nil
      if self.id != nil
        self.rmembers << 'id'
      end
      return self.rmembers
    end
    
    members = obj.instance_variables.map{|mem| mem[1,mem.length]}
    if self.id != nil
      members << 'id'
    end
    members
  end
  
  def to_hash
    hash= {}
    members = self.get_members
    members.each do |m|
      hash[m] = eval("self.#{m}")
    end
    if !self.id.nil?
      hash['id'] = self.id
    end
    hash
  end
end