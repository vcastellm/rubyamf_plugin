#This stores supporting configuration classes used in the config file to register class mappings and parameter mappings etc.
require 'app/request_store'
require 'exception/rubyamf_exception'
module RubyAMF
  module Configuration
    #ClassMappings configuration support class
    class ClassMappings
      
      # these NEED to be outside the class << self to work
      @ignore_fields = ['created_at','created_on','updated_at','updated_on']
      @translate_case = false
      @class_mappings_by_ruby_class = {}
      @class_mappings_by_actionscript_class = {}
      @scoped_class_mappings_by_ruby_class = {}
      @attribute_names = {}
      @hash_key_access = :symbol
      @translate_case = false
      @force_active_record_ids = true
      @assume_types = false
      @use_ruby_date_time = false
      @use_array_collection = false
      @check_for_associations = true
      
      # Aryk: I cleaned up how the class variables are called here. It doesnt matter if you use class variables or instance variables on the class level. Check out this simple tutorial
      # - http://sporkmonger.com/2007/2/19/instance-variables-class-variables-and-inheritance-in-ruby      
     
      class << self           
        include RubyAMF::App
        include RubyAMF::Exceptions 
        
        attr_accessor :ignore_fields, :use_array_collection, :default_mapping_scope, :force_active_record_ids, :attribute_names, 
          :use_ruby_date_time, :current_mapping_scope, :check_for_associations, :translate_case, :assume_types, :hash_key_access  #the rails parameter mapping type
        
        def register(mapping)  #register a value object map
          #build out ignore field logic
          hashed_ignores = {}
          ClassMappings.ignore_fields.to_a.each{|k| hashed_ignores[k] = true} # strings and nils will be put into an array with to_a
          mapping[:ignore_fields].to_a.each{|k| hashed_ignores[k] = true}
          mapping[:ignore_fields] = hashed_ignores # overwrite the original ignore fields

          # if they specify custom attributes, ensure that AR ids are being passed as well if they opt for it.
          if force_active_record_ids && mapping[:attributes] && mapping[:type]=="active_record" && !mapping[:attributes].include?("id")
            mapping[:attributes] << "id"
          end
          
          # created caching hashes for mapping
          @class_mappings_by_ruby_class[mapping[:ruby]] = mapping # for quick referencing purposes
          @class_mappings_by_actionscript_class[mapping[:actionscript]] = mapping # for quick referencing purposes
          @scoped_class_mappings_by_ruby_class[mapping[:ruby]] = {} # used later for caching based on scope (will get cached after the first run)
          # for deserialization - looking up in a hash is faster than looking up in an array.
          begin
            if mapping[:type] == "active_record" 
              @attribute_names[mapping[:ruby]] = (mapping[:ruby].constantize.new.attribute_names + ["id"]).inject({}){|hash, attr| hash[attr]=true ; hash} # include the id attribute
            end
          rescue ActiveRecord::StatementInvalid => e
            # This error occurs during migrations, since the AR constructed above will check its columns, but the table won't exist yet.
            # We'll ignore the error if we're migrating.
            raise unless ARGV.include?("migrate") or ARGV.include?("db:migrate")
          end
        end
        
        def get_vo_mapping_for_ruby_class(ruby_class)
          return unless scoped_class_mapping = @scoped_class_mappings_by_ruby_class[ruby_class] # just in case they didnt specify a ClassMapping for this Ruby Class
          scoped_class_mapping[@current_mapping_scope] ||= (if vo_mapping = @class_mappings_by_ruby_class[ruby_class]
              vo_mapping = vo_mapping.dup # need to duplicate it or else we will overwrite the keys from the original mappings
              vo_mapping[:attributes]   = vo_mapping[:attributes][@current_mapping_scope]||[]   if vo_mapping[:attributes].is_a?(Hash)      # don't include any of these attributes if there is no scope
              vo_mapping[:associations] = vo_mapping[:associations][@current_mapping_scope]||[] if vo_mapping[:associations].is_a?(Hash) # don't include any of these attributes
              vo_mapping
            end
          )
        end
        
        def get_vo_mapping_for_actionscript_class(actionscript_class)
          @class_mappings_by_actionscript_class[actionscript_class]
        end    
      end
    end
    
    class ParameterMappings
      @parameter_mappings = {}
      @always_add_to_params = true
      @scaffolding = false
      
      class << self
        
        attr_accessor :scaffolding, :always_add_to_params
        
        def register(mapping)
          raise RUBYAMFException.new(RUBYAMFException.USER_ERROR, "You must atleast specify the :controller for a parameter mapping") unless mapping[:controller]
          set_parameter_mapping(mapping[:controller], mapping[:action], mapping)
        end
        
        def update_request_parameters(controller_class_name, controller_action_name, request_params,  rubyamf_params, remoting_params)
          if map = get_parameter_mapping(controller_class_name, controller_action_name)
            map[:params].each do |k,v|
              val = eval("remoting_params#{v}")
              if scaffolding && val.is_a?(ActiveRecord::Base)
                request_params[k.to_sym] = val.attributes.dup
                val.instance_variables.each do |assoc|
                  next if "@new_record" == assoc
                  request_params[k.to_sym][assoc[1..-1]] = val.instance_variable_get(assoc)
                end
              else
                request_params[k.to_sym] = val
              end
              rubyamf_params[k.to_sym]  = request_params[k.to_sym] # assign it to rubyamf_params for consistency
            end
          else #do some default mappings for the first element in the parameters
            if remoting_params.is_a?(Array)
              if scaffolding
                if (first = remoting_params[0])
                  if first.is_a?(ActiveRecord::Base)
                    key = first.class.to_s.downcase.to_sym
                    rubyamf_params[key] = first.attributes.dup
                    first.instance_variables.each do |assoc|
                      next if "@new_record" == assoc
                      rubyamf_params[key][assoc[1..-1]] = first.instance_variable_get(assoc)
                    end
                    if always_add_to_params #if wanted in params, put it in
                      request_params[key] = rubyamf_params[key] #put it into rubyamf_params
                    end
                  else
                    if first.is_a?(VoHash)
                      if (key = first.explicitType.split('::').last.downcase.to_sym)
                        rubyamf_params[key] = first
                        if always_add_to_params
                          request_params[key] = first
                        end
                      end
                      request_params[:id] = rubyamf_params[:id] = first['id'] if first['id'] && !first['id']==0
                    end
                  end
                end
              end
            end
          end
        end
        
        private
        def get_parameter_mapping(controller_class_name, controller_action_name) 
          @parameter_mappings[end_point_string(controller_class_name, controller_action_name)]|| # first check to see if there is a paramter mapping for the controller/action combo, 
          @parameter_mappings[end_point_string(controller_class_name)] # then just check if there is one for the controller
        end
        
        def set_parameter_mapping(controller_class_name, controller_action_name, mapping)
          @parameter_mappings[end_point_string(controller_class_name, controller_action_name)] = mapping
        end
        
        def end_point_string(controller_class_name, controller_action_name=nil) # if the controller_action_name is nil, than we the parameter mapping is for the entire controller
          eps = controller_class_name.to_s.dup # could be a symbol from the class mapping ; need to dup because it will recursively append the action_name
          eps << ".#{controller_action_name}" if controller_action_name
          eps
        end
        
      end 
    end
  end
end
