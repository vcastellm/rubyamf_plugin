#utility method to get a vo object mapping from the vo_mappings module
require 'app/configuration'
require 'app/request_store'
require 'exception/rubyamf_exception'
include RUBYAMF::Configuration

class VoUtil
  def self.get_vo_for_incoming(os,classname)
    begin      
      #obj will always be an open struct, it's the classname that tells me what to map to
      mappings = ValueObjects.get_vo_mappings
            
      #if no mappings return the OpenStruct
      if mappings.empty? || mappings.nil?
        return os
      end
      
      vo = nil
      vomap = nil
      active_rec = false
      mappings.each do |map|
        if map[:incoming] == classname
          vomap = map #store vomap
          if map[:type] != nil && map[:type].to_s == 'active_record'
            os._explicitType = map[:map_to]
            vo = self.get_active_record_from_open_struct(os)
            active_rec = true
            break
          else
            filepath = map[:map_to].split('.').join('/').to_s + '.rb' #set up filepath from the map_to symbol
            load(ValueObjects.vo_path + '/' + filepath) #require the file
            vo = Object.const_get(classname.split('.').last).new #this returns an instance of the VO
            break
          end
        end
      end
      
      #if this was an active record VO, return it prematurely
      if active_rec
        return vo
      end
      
      #vo wasn't created, just return the open struct
      if vo == nil
        return os
      end
      
      #assign values to new VO object
      members = os.get_members
      members.each do |member|
        prop = ValueObjects.translate_case ? member.snake_case : member
        eval("vo.#{prop} = os.#{member}")
      end
      
      #Assing RubyAMF tracking vars
      vo._explicitType = vomap[:map_to] #assign the VO it's 'mapped_to' classname
      #vo.rmembers = members
      vo
    rescue LoadError => le
      raise RUBYAMFException.new(RUBYAMFException.VO_ERROR, "Tho VO definition #{classname} could not be found. #{le.message}")
    end
  end
  
  def self.get_vo_for_outgoing(obj)
    begin
      if obj._explicitType != nil
        classname = obj._explicitType
      else
        classname = obj.class.to_s
      end

      vo = nil
      vomap = nil
      mappings = ValueObjects.get_vo_mappings
      mappings.each do |map|
        if map[:map_to] == classname
          vomap = map
          obj._explicitType = map[:outgoing]
          break;
        end
      end
      return obj
    rescue Exception => e
      raise RUBYAMFException.new(RUBYAMFException.VO_ERROR, e.message)
    end
  end
  
  #get a mapping from an active record instance, used in active record adapter
  def self.get_vo_definition_from_active_record(classname)
    mappings = ValueObjects.get_vo_mappings
    mappings.each do |map|
      if map[:map_to] == classname
        return map
      end
    end
    nil
  end
  
  #make an init hash for AR from an open struct
  def self.make_hash_for_active_record_from_open_struct(os)
    hash = {}
    members = os.get_members
    members.each do |key|
      if key == '_explicitType' || key == 'rmembers'
        next
      end
      val = os.send(:"#{key}")
      hash[key] = val
    end
    hash
  end
  
  #get an active record from an incoming VO openStruct
  def self.get_active_record_from_open_struct(os)
    self.camels_to_snakes!(os) if ValueObjects.translate_case
    if os._explicitType == nil
      return nil
    end

    if os._explicitType.include?('.')
      classname = os._explicitType.split('.').last
    else
      classname = os._explicitType
    end

    hash = self.make_hash_for_active_record_from_open_struct(os)
    
    os.get_members.each do |k| #go through each value in the object, if it's nil don't put it in the update hash
      val = os.send(:"#{k}")
      #delete incoming members that are nil/NaN or if we explicitly ignore it because of magic_fields
      if ActiveRecord::Base.magic_fields.include?(k) || val == nil || val == NaN
        os.delete_field(k.to_sym)
        os.delete_field(k.to_s)
        hash.delete(k.to_s)
        next
      end
    end
    
    #catch active record errors
    begin
      if os.id != 0 && os.id.to_s != 'NaN' && os.id != nil
        ActiveRecord::Base.update_nil_associations(Object.const_get(classname),hash,os,true) #update the hash so nil assotiations don't mess up AR
        ar = Object.const_get(classname).find(os.id)
      else
        ActiveRecord::Base.update_nil_associations(Object.const_get(classname),hash,os,false) #update the hash so nil assotiations don't mess up AR
        ActiveRecord::Base.update_nans(hash)
        ar = Object.const_get(classname).new(hash)
      end
    rescue Exception => e
      raise
    end
    
    #store the original vo for later, (in the RailsInvokeAction)
    ar.original_vo_from_deserialization = os
    return ar
  end
  
  #if we're expecting vo camel case properties to be mapped to ar snake case properties, fix
  #open struct representations here
  def self.camels_to_snakes!(os)
    os.get_members.each do |k|                                                               
      val = os.send(:"#{k}")
      if k.snake_case != k && k != '_explicitType' && k != 'amf_id'
        if val
          eval("os.#{k.snake_case} = os.#{k}")
        else
          eval("os.#{k.snake_case} = nil")
        end
        os.delete_field("#{k}")
      end
    end
  end
end