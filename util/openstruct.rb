class OpenStruct
  
  def get_members
    if self.rmembers != nil
      if self.id != nil
        self.rmembers << 'id'
      end
      return self.rmembers
    end
    
    members = self.marshal_dump.keys.map{|k| k.to_s}
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