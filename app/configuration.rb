require 'app/request_store'
include RUBYAMF::App

#This stores supporting configuration classes used in the config file to register, adapters, vo's, application instances, etc.
module RUBYAMF
module Configuration

#Application::Instance support class
class Application
  
  module Instance
    @@app_instances = []
    
    #register's an application instance
    def Instance.register(definition)
      if definition[:source] == nil || definition[:source] == ''
        return nil
      end
      if definition[:name] == nil || definition[:name] == ''
        return nil
      end
      if @@app_instances == nil
        @@app_instances = []
      end
      @@app_instances << definition
    end
    
    #Get an application instance definition from a target service
    def Instance.getAppInstanceDefFromTargetService(source)
      if source.nil?
        return nil
      end
      
      final_ai = nil
      @@app_instances.each do |ai|
        m = ai[:source].clone
        #create a simple regex here from a source package
        #org.rubyamf.amf.* => org\.rubyamf\.amf\..*
        #used to match against the ai[:source]
        m.gsub!('.','\.')
        m.gsub!('*','.*')
        if source.match(m)
          return ai
        end        
      end
      nil
    end
  end
end

#Adapters configuration support class
class Adapters
  @@adapters = []
  def Adapters.register(file,classname)
    @@adapters << [file,classname]
  end
  
  def Adapters.get_adapters
    @@adapters
  end
  
  def Adapters.get_adapter_for_result(res)
    if @@adapters.nil?
      return false
    end
    @@adapters.each do |adapter|
      require RequestStore.adapters_path + adapter[0]
      adapter = Object.const_get(adapter[1]).new
      if adapter.use_adapter?(res)
        return adapter
      end
    end
    false
  end
    
  class << self
    attr_accessor :deep_adaptations
  end
end

#ValueObjects configuration support class
class ValueObjects
    
  @@vo_mappings = []
  @@vo_by_instances_lookup = {}
  @@mapping_type = ''
  @@translate_case = false
  @@vo_path = ''

  #register a value object map
  def ValueObjects.register(hash)
    if hash[:instance] != nil
      if @@vo_by_instances_lookup[hash[:instance]].nil?
        @@vo_by_instances_lookup[hash[:instance]] = []
      end
      @@vo_by_instances_lookup[hash[:instance]] << hash
    else
      @@vo_mappings << hash
    end
  end
    
  #Get ValueObject mappings for this request
  def ValueObjects.get_vo_mappings
    maps = []
    #If no application instance has been defined for this request, just return all ValueObjects
    if RequestStore.app_instance == nil
      if !@@vo_mappings.empty? #if some global value objects are available, put them in the maps array
        maps.concat(@@vo_mappings)
      end
      return maps
    else
      instance = RequestStore.app_instance[:name]
      #puts instance specific VO's into the maps array
      if !@@vo_by_instances_lookup.empty?
        if @@vo_by_instances_lookup[instance] != nil
          maps.concat(@@vo_by_instances_lookup[instance])
        end
      end
      
      #now put non app specific ValueObjects into maps array
      if !@@vo_mappings.empty?
        maps.concat(@@vo_mappings)
      end
    end
    maps
  end
  
  #the rails parameter mapping type
  def ValueObjects.rails_parameter_mapping_type=(val)
    @@mapping_type = val
  end
  
  #the rails parameter mapping type
  def ValueObjects.rails_parameter_mapping_type
    @@mapping_type
  end
  
  def ValueObjects.translate_case
    @@translate_case
  end
  
  def ValueObjects.translate_case=(v)
    @@translate_case = v
  end
  
  #the rails parameter mapping type
  def ValueObjects.vo_path=(val)
    @@vo_path = val
  end
  
  #the rails parameter mapping type
  def ValueObjects.vo_path
    @@vo_path
  end
end

class Parameter
  module Map
    @@maps = []
    
    def self.register(mapping)
      @@maps << mapping
    end
    
    def self.get_maps
      @@maps
    end
    
    def self.eval_string(str)
      str = str.gsub!("{","[")
      str = str.gsub!("}","]")
      return str
    end
    
    def self.update_request_parameters(target_uri,railsparams,remotingparams)
      begin
        maps = []
        @@maps.each do |map|
          if ("#{map[:controller].to_s}.#{map[:action]}") == target_uri || (map[:controller].to_s == target_uri)
            maps << map
          end
        end
        if maps.empty? then return nil end
        maps.each do |var|
          var[:params].each do |k,v|
            accessor = self.eval_string(v.clone)
            val = eval("remotingparams#{accessor}")
            railsparams[k.to_sym] = val
            if val.is_a?(ActiveRecord::Base) && val.id != nil && val.id != 'NaN' && val.id != NaN && val.id != 'undefined'
              #first put the update parameters in to the hash, then add the right id
              railsparams[k.to_sym] = val.original_vo_from_deserialization.to_hash
              railsparams[k.to_sym][:id] = val.id
            elsif val.is_a?(ActiveRecord::Base) && (val.id == nil || val.id = 'NaN' || val.id == 'undefined')
              railsparams[k.to_sym] = val.original_vo_from_deserialization.to_hash
            end
          end
        end
      rescue Exception => e
        raise
      end
    end
  end
end
end
end