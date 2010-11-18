module RubyAMF
  module VoHelper
    class VoHash < Hash
      attr_accessor :_explicitType
      
      def ==(other)
        other.is_a?(VoHash) && !_explicitType.nil? && _explicitType == other._explicitType && super
      end
      
    end
    
    require 'app/configuration' # cant put this at the top because VoHash has to be instantiated for app/configuration to work
    class VoUtil
      
      include RubyAMF::Configuration
      include RubyAMF::Exceptions
      
      def self.get_ruby_class(action_class_name)
        mapping = ClassMappings.get_vo_mapping_for_actionscript_class(action_class_name)
        if mapping
          return mapping[:ruby].constantize
        else
          begin 
            assumed_class = action_class_name.constantize
            assumed_class.new
            assumable=true
          rescue
            assumable=false
          ensure
            if ClassMappings.assume_types && assumable && assumed_class!=nil
              return assumed_class
            else
              case ClassMappings.hash_key_access
              when :symbol then return Hash
              when :string then return Hash
              when :indifferent then return HashWithIndifferentAccess
              end
            end            
          end
        end
      end      
      
      def self.set_value(obj, key, value)
        if obj.kind_of?(ActiveRecord::Base)
          #ATTRIBUTE
          attributes = obj.instance_variable_get('@attributes')
          attribs = (obj.attribute_names + [obj.class.primary_key]).inject({}){|hash, attr| hash[attr]=true ; hash} # fosrias: includes custom primary keys
          mapping = ClassMappings.get_vo_mapping_for_ruby_class(obj.class.name)
          if (!mapping && attribs[key]) || 
            (mapping && !mapping[:ignore_fields].include?(key) && ClassMappings.attribute_names[mapping[:ruby]][key])                  
            attributes[key] = value
            obj.send("#{key}_will_change!")  #fosrias: flags the attribute to change with partial_updates
          #ASSOCIATION
          elsif reflection = obj.class.reflections[key.to_sym] # is it an association
            case reflection.macro  
            when :has_one
              obj.send("set_#{key}_target", value) if value
            when :belongs_to
              obj.send("#{key}=", value) if value
            when :has_many, :has_and_belongs_to_many
              obj.send("#{key}").target = value if value
            when :composed_of
              obj.send("#{key}=", value) if value # this sets the attributes to the corresponding values
            end
          elsif
             # build @methods hash
          if mapping[:methods]
              @methods = Hash.new if !@methods
              @methods[obj.class.name]=Hash.new if !@methods[obj.class.name]
              mapping[:methods].each do |method|
                if method == key
                  @methods[obj.class.name]["#{key}"] = value
                end
              end
          end
          else
            obj.instance_variable_set("@#{key}", value)
          end
        elsif obj.kind_of? ActiveResource::Base 
          # fosrias: if assume_types = true and there is no mapping, all attributes will be mapped since there is no way to tell the related model's attributes. 
          # Use [Transient] tag in flex/flash classes to prevent mapping in this case for local properties.
          attributes = obj.instance_variable_get('@attributes')
          mapping = ClassMappings.get_vo_mapping_for_ruby_class(obj.class.name)
          if (!mapping || mapping && !mapping[:ignore_fields].include?(key))      
            attributes[key] = value
          end
        elsif obj.kind_of? Hash
          obj[key] = value
        else
          raise RUBYAMFException.new(RUBYAMFException.VO_ERROR, "Argument, #{obj}, is not an ActiveRecord::Base or a Hash.")
        end
      end
             
      def self.finalize_object(obj)
        if obj.kind_of? ActiveRecord::Base
          attributes = obj.instance_variable_get('@attributes')
          primary_key = obj.class.primary_key # fosrias: allows for custom primary keys
          attributes.delete(primary_key) if attributes[primary_key]==0 || attributes[primary_key]==nil # fosrias: primary_key attribute cannot be zero or nil
          attributes['type']=obj.class.name if  attributes['type']==nil && obj.class.superclass!=ActiveRecord::Base #STI: Always need 'type' on subclasses.
          attributes[obj.class.locking_column]=0 if obj.class.locking_column && attributes[obj.class.locking_column]==nil #Missing lock_version is equivalent to 0.
          attributes.delete('lock_version') if attributes['lock_version']==nil || attributes['lock_version']==0 #Always need lock_version on ActiveRecords that use it, even if it's not defined on ModelObject or mapped correctly. 
          if primary_key != 'id'
            if obj.id && obj.class.exists?(obj.id.to_s) # fosrias: no other way to tell with custom primary keys
              if Rails::VERSION::MAJOR < 3 # fosrias: new record tracking changed
                obj.instance_variable_set("@new_record", false)
              else
                obj.instance_variable_set("@persisted", true)
              end
            end
          else
             if Rails::VERSION::MAJOR < 3 # fosrias: new record tracking changed
                obj.instance_variable_set("@new_record", false) if attributes['id'] # the record already exists in the database
              else
                obj.instance_variable_set("@persisted", true) if attributes['id'] # the record already exists in the database
              end
          end
          #superstition
          if (obj.new_record?)
            obj.created_at = nil if obj.respond_to? "created_at"
            obj.created_on = nil if obj.respond_to? "created_on"
            obj.updated_at = nil if obj.respond_to? "updated_at"
            obj.updated_on = nil if obj.respond_to? "updated_on"
            obj.instance_variable_set("@changed_attributes", {}) # fosrias: only set changed attributes for existing records
          end
    
		end
    
		if obj.kind_of?(ActiveRecord::Base) || obj.kind_of?(ActiveResource::Base)
          # process @methods hash
          if @methods 
            @methods.delete(obj.class.name).each do |key, value|
              obj.send("#{key}=", value)
            end if @methods[obj.class.name]
            
            # fosrias: Process method related attributes passed back if they have a setter defined
			# Allows setting attr_accessors as methods on ActiveRecord or ActiveResource objects.
            @methods.each do |key, value|
              obj.send("#{key}=", value) if obj.respond_to?("#{key}=")
            end
          end
        end
      end
      
      #moved logic here so AMF3 and AMF0 can use it
      def self.get_vo_for_incoming(obj,action_class_name)
        ruby_obj = VoUtil.get_ruby_class(action_class_name).new
        if ruby_obj.kind_of?(ActiveRecord::Base) 
          obj.each_pair{|key, value| VoUtil.set_value(ruby_obj, key, value)}
          VoUtil.finalize_object(ruby_obj)
          return ruby_obj
        else
          case ClassMappings.hash_key_access
          when :symbol then return obj.symbolize_keys!
          when :string then return obj # by default the keys are a string type, so just return the obj
          when :indifferent then return HashWithIndifferentAccess.new(obj)
          # else  # TODO: maybe add a raise FlexError since they somehow put the wrong value for this feature
          end
        end
      end

      # Aryk: I tried to make this more efficent and clean.
      def self.get_vo_hash_for_outgoing(obj)
        new_object = VoHash.new #use VoHash because one day, we might do away with the class Object patching
        instance_vars = obj.instance_variables
        methods = []
        if map = ClassMappings.get_vo_mapping_for_ruby_class(obj.class.to_s)
          if map[:type]=="active_record"
            attributes_hash = obj.attributes
            (map[:attributes]||attributes_hash.keys).each do |attr| # need to use dup because sometimes the attr is frozen from the AR attributes hash
              attr_name = attr
              attr_name = attr_name.dup.to_camel! if ClassMappings.translate_case # need to do it this way because the string might be frozen if it came from the attributes_hash.keys
              new_object[attr_name] = attributes_hash[attr]
            end
            instance_vars = [] # reset the instance_vars for the associations, this way no unwanted instance variables (ie @new_record, @read_only) can get through
            # Note: if you did not specify associations, it will not show up even if you eager loaded them.
            if map[:associations] # Aryk: if they opted for assocations, make sure that they are loaded in. This is great for composed_of, since it cannot be included on a find
              map[:associations].each do |assoc|
                instance_vars << ("@"+assoc) if obj.send(assoc) # this will make sure they are instantiated and only load it if they have a value.
              end
            elsif ClassMappings.check_for_associations
              instance_vars = obj.instance_variables.reject{|assoc| ["@attributes","@new_record","@read_only","@attributes_cache"].include?(assoc)}
            end
            
            # if there are AR methods they want in the AS object as an attribute, see about them here.
            if map[:methods]
              map[:methods].each do |method|
                methods << method if obj.respond_to?(method)
              end
            end
          elsif map[:type]=="active_resource" # fosrias: without this, attributes is one of the two instance variables and it will not map the individual attributes. Elseif for speed so only checked if not active record.
            instance_vars = obj.instance_variable_get("@attributes").collect do |attribute_pair|
              attr_name = "@#{attribute_pair[0]}"
              obj.instance_variable_set(attr_name, attribute_pair[1])
              attr_name
            end
            if map[:associations] # Aryk: if they opted for assocations, make sure that they are loaded in. This is great for composed_of, since it cannot be included on a find
              # fosrias: not implemented
            elsif ClassMappings.check_for_associations
              # fosrias: not implemented
            end
          end
          new_object._explicitType = map[:actionscript] # Aryk: This only works on the Hash because rubyAMF extended class Object to have this accessor, probably not the best idea, but its already there.   
          # Tony: There's some duplication in here. Had trouble consolidating the logic though. Ruby skills failed.
        elsif ClassMappings.assume_types
          new_object._explicitType = obj.class.to_s
          if obj.is_a?(ActiveRecord::Base)
            obj.attributes.keys.each do |key|
              attr_name = key
              attr_name = attr_name.dup.to_camel! if ClassMappings.translate_case # need to do it this way because the string might be frozen if it came from the attributes_hash.keys
              new_object[attr_name] = obj.attributes[key]
            end
            instance_vars = []
            if ClassMappings.check_for_associations
              instance_vars = obj.instance_variables.reject{|assoc| ["@attributes","@new_record","@read_only","@attributes_cache"].include?(assoc)}
            end
          elsif obj.is_a?(ActiveResource::Base) # fosrias: without this, attributes is one of the two instance variables and it will not map the individual attributes. Elseif for speed so only checked if not active record.
            instance_vars = obj.instance_variable_get("@attributes").collect do |attribute_pair|
              attr_name = "@#{attribute_pair[0]}"
              obj.instance_variable_set(attr_name, attribute_pair[1])
              attr_name
            end
            if ClassMappings.check_for_associations
              # fosrias: not implemented
            end
          end
        elsif obj.is_a?(ActiveResource::Base) # fosrias: Need this for case of no mapping and assumed_types = false.
            instance_vars = obj.instance_variable_get("@attributes").collect do |attribute_pair|
              attr_name = "@#{attribute_pair[0]}"
              obj.instance_variable_set(attr_name, attribute_pair[1])
              attr_name
            end
            if ClassMappings.check_for_associations
              # fosrias: not implemented
            end
          end
        instance_vars.each do |var| # this also picks up the eager loaded associations, because association called "has_many_assoc" has an instance variable called "@has_many_assoc"
          attr_name = var[1..-1]
          attr_name.to_camel! if ClassMappings.translate_case
          new_object[attr_name] = obj.instance_variable_get(var)
        end
        methods.each do |method|
          attr_name = method.dup
          attr_name.to_camel! if ClassMappings.translate_case
          new_object[attr_name] = obj.send(method)
        end
        new_object
      rescue Exception => e
        puts e.message
        # puts e.backtrace
        raise RUBYAMFException.new(RUBYAMFException.VO_ERROR, e.message)
      end
    end
  end
end
