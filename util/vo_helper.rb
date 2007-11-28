module RubyAMF
  module VoHelper
    class VoHash < Hash
      attr_accessor :_explicitType
    end
    
    require 'app/configuration' # cant put this at the top because VoHash has to be instantiated for app/configuration to work
    class VoUtil
      
      include RubyAMF::Configuration
      include RubyAMF::Exceptions
      
      #moved logic here so AMF3 and AMF0 can use it
      def self.get_vo_for_incoming(obj,action_class_name)
        if (mapping = ClassMappings.get_vo_mapping_for_actionscript_class(action_class_name)) || ## if there is a map use, that class
          (ruby_obj = ClassMappings.assume_types&&(action_class_name.constantize.new rescue false)) # if no map, and try to get the assumed type
          if mapping #if there's a map, then we default to it's specification.
            obj.reject!{|k,v| mapping[:ignore_fields][k]}
            ruby_obj = mapping[:ruby].constantize.new
          end            
          if ruby_obj.is_a?(ActiveRecord::Base)        # put all the attributes fields into the attribute instance variable
            attributes = {} # extract attributes
            if mapping
              obj.each_key do |field|
                if ClassMappings.attribute_names[mapping[:ruby]][field]
                  attributes[field] = obj.delete(field)
                end
              end
            else # for assumed types when there is no mapping
              attribs = (ruby_obj.attribute_names + ["id"]).inject({}){|hash, attr| hash[attr]=true ; hash}
              obj.each_key do |field|
                if attribs[field]
                  attributes[field] = obj.delete(field)
                end
              end
            end
            attributes.delete("id") if attributes["id"]==0 # id attribute cannot be zero
            ruby_obj.instance_variable_set("@attributes", attributes) # bypasses any overwriting of the attributes=(value) method  (also allows 'id' to be set)
            ruby_obj.instance_variable_set("@new_record", false) if attributes["id"] # the record already exists in the database
            obj.each_key do |field|
              if reflection = ruby_obj.class.reflections[field.to_sym] # is it an association
                value = obj.delete(field) # get rid of the field so it doesnt get added in the next loop
                case reflection.macro  
                when :has_one
                  ruby_obj.send("set_#{field}_target", value)
                when :belongs_to
                  ruby_obj.send("#{field}=", value)
                when :has_many, :has_many_and_belongs_to
                  ruby_obj.send("#{field}").target = value
                when :composed_of
                  ruby_obj.send("#{field}=", value) # this sets the attributes to the corresponding values
                end
              end
            end
          end
          obj.each do |field, value| # whatever is left, set them as instance variables in the object
            ruby_obj.instance_variable_set("@#{field}", value)
          end
          ruby_obj
        else # then we are still left with a normal hash, lets see if we need to change the type of the keys
          case ClassMappings.hash_key_access
          when :symbol      : obj.symbolize_keys!
          when :string      : obj # by default the keys are a string type, so just return the obj
          when :indifferent : HashWithIndifferentAccess.new(obj)
          # else  # TODO: maybe add a raise FlexError since they somehow put the wrong value for this feature
          end
        end
      end
            
      # Aryk: I tried to make this more efficent and clean.
      def self.get_vo_hash_for_outgoing(obj)
        new_object = VoHash.new #use VoHash because one day, we might do away with the class Object patching
        instance_vars = obj.instance_variables
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
              instance_vars = obj.instance_variables.reject{|assoc| ["@attributes","@new_record","@read_only"].include?(assoc)}
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
              instance_vars = obj.instance_variables.reject{|assoc| ["@attributes","@new_record","@read_only"].include?(assoc)}
            end
          end
        end
        instance_vars.each do |var| # this also picks up the eager loaded associations, because association called "has_many_assoc" has an instance variable called "@has_many_assoc"
          attr_name = var[1..-1]
          attr_name.to_camel! if ClassMappings.translate_case
          new_object[attr_name] = obj.instance_variable_get(var)
        end
        new_object
      rescue Exception => e
        puts e.message
        puts e.backtrace
        raise RUBYAMFException.new(RUBYAMFException.VO_ERROR, e.message)
      end
    end
  end
end
