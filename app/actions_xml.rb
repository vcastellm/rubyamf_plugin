require 'app/request_store'
require 'app/configuration'
require 'exception/rubyamf_exception'
require 'ostruct'
require RUBYAMF_HELPERS + 'active_record_connector'
include RUBYAMF::App
include RUBYAMF::Exceptions
include RUBYAMF::Configuration
module RUBYAMF
module Actions

#This sets up each body for processing
class PrepareAction
  def run(amfbody)
    RequestStore.flex_messaging = false #reset to false
    if RequestStore.amf_encoding == 'amf3' #AMF3
      tmp_val = amfbody.value[0]
      if tmp_val.is_a?(OpenStruct)
        if tmp_val._explicitType == 'flex.messaging.messages.RemotingMessage' #Flex Messaging setup
          RequestStore.flex_messaging = true
  				amfbody.special_handling = 'RemotingMessage'
  				amfbody.value = tmp_val.body
  				amfbody.special_handling = 'RemotingMessage'
  				amfbody.set_meta('clientId', tmp_val.clientId)
  				amfbody.set_meta('messageId', tmp_val.messageId)
          amfbody.target_uri = tmp_val.source
          amfbody.service_method_name = tmp_val.operation
          amfbody._explicitType = 'flex.messaging.messages.RemotingMessage'
  				amfbody.set_amf3_class_file_and_uri
        elsif tmp_val._explicitType == 'flex.messaging.messages.CommandMessage' #it's a ping, don't process this body
          if tmp_val.operation == 5
            amfbody.exec = false
            amfbody.special_handling = 'Ping'
    				amfbody.set_meta('clientId', tmp_val.clientId)
    				amfbody.set_meta('messageId', tmp_val.messageId)
    			end
        else #is amf3, but set these props the same way as amf0, and not flex
          amfbody.set_amf0_class_file_and_uri
          amfbody.set_amf0_service_and_method
        end
      else #is amf3, but set these props the same way as amf0, and not flex
        amfbody.set_amf0_class_file_and_uri
        amfbody.set_amf0_service_and_method
      end
    elsif RequestStore.amf_encoding == 'amf0' #AMF0
      amfbody.set_amf0_class_file_and_uri
      amfbody.set_amf0_service_and_method
    end    
  end  
end

#Loads the file that contains the service method you are calling.
class ClassAction
	def run(amfbody)
	  if amfbody.exec == false
      return
    end
	  
	  if RequestStore.rails
	    amfbody.class_file = amfbody.class_file.snake_case #=> MyController -> my_controller
	  end
	  
		filename = RequestStore.service_path + amfbody.class_file_uri + amfbody.class_file
		$:.unshift(RequestStore.service_path) #add the service location to load path
    
    if RequestStore.reload_services
      begin
        Object.send('remove_const',amfbody.service_name)
      rescue Exception => e #do nothing, the first time running the const won't ever exist, just suppres it
      end
    end
    
	  begin
		  load(filename) #load the file
		rescue LoadError => le
		  raise RUBYAMFException.new(RUBYAMFException.LOAD_CLASS_FILE, "Error loading file - #{le.to_s}")
		rescue TypeError => te
		  if te.message.match(/superclass mismatch/) == nil
		    raise RUBYAMFException.new(RUBYAMFException.LOAD_CLASS_FILE, "There was an error loading #{filename} - #{e.to_s}")
		  end
	  rescue Exception => e
		  raise RUBYAMFException.new(RUBYAMFException.LOAD_CLASS_FILE, "There was an error loading #{filename} - #{e.to_s}")
	  ensure
		  $:.shift #clear the service path that was put into the load path array
	  end
	end
end

#This takes an AMFBody and initializes the Application::Instance that was registered for the target service (org.rubyamf.amf.AMFTesting)
class ApplictionInstanceInitAction
  include ActiveRecordConnector #include the connector
  def run(amfbody)    
    #get the application instance definition
    applicationInstanceDefinition = Application::Instance.getAppInstanceDefFromTargetService(amfbody.target_uri)
    if applicationInstanceDefinition.nil?
      return nil
    end
    
    #store the app instnace definition
    RequestStore.app_instance = applicationInstanceDefinition
        
    should_connect = false
    require_models = false
    
    if applicationInstanceDefinition[:initialize] == 'active_record'
      begin
        should_connect = true
        require_models = true if !applicationInstanceDefinition[:models_path].nil?
        require 'rubygems'
        require 'active_record'
        $:.unshift(RUBYAMF_CORE) #ensure the rubyamf_core load path is still first
      rescue LoadError => e
        raise RUBYAMFException.new(RUBYAMFException.USER_ERROR, "You have a Value Object defined that use ActiveRecord, but the ActiveRecord gem is not installed.")
      end
    end
      
    connected = false
    #connect ActiveRecord if needed
    if should_connect
      begin
        yamlfile = applicationInstanceDefinition[:database_config]
        if yamlfile.nil?
          raise RUBYAMFException.new(RUBYAMFException.USER_ERROR, "You must specify the :database_config option in your Application Instance Definition (in rubyamf_config). In order for ActiveRecord to connect properly.")
        end
        if !applicationInstanceDefinition[:database_node].nil?
          ar_connect(yamlfile, applicationInstanceDefinition[:database_node])
        else
          ar_connect(yamlfile, 'default')
        end
      rescue ActiveRecord::ActiveRecordError => e
        raise RUBYAMFException.new(RUBYAMFException.USER_ERROR, "ActiveRecord could not connect to the database, check that your database_config file is using the correct information. {#{e.message}}")
      rescue Exception => e
        raise RUBYAMFException.new(RUBYAMFException.USER_ERROR, "An error occured while connecting your applications ActiveRecord definition {#{e.message}}")
      end
      connected = true
    end
    
    #if we get past the block above somehow but didn't connect
    if connected == false && require_models
      if applicationInstanceDefinition[:database_config]
        raise RUBYAMFException.new(RUBYAMFException.USER_ERROR, "An error occured while instantiating your application instance. You specified that you want to require Active Record models, but ActiveRecord could not connect propertly, double check your database configuration yaml file.")
      elsif applicationInstanceDefinition[:database_config].nil?
        raise RUBYAMFException.new(RUBYAMFException.USER_ERROR, "An error occured while instantiating your application instance. You specified that you want to require Active Record models, but you did not specify a database_config file, see the default 'rubyamf_config.rb' file in services for an example.")
      end
    end
    
    #require all the user models if needed
    if require_models && connected
      models_path = applicationInstanceDefinition[:models_path]
      files = Dir.glob(RUBYAMF_SERVICES + models_path)
      if files.empty? then return nil end
      begin
        $:.unshift(RUBYAMF_SERVICES)
        files.each do |file|
          require file
        end
        $:.shift
      rescue LoadError => e
        raise RUBYAMFException.new(RUBYAMFException.USER_ERROR, "An error occured while loading your application models {#{e.message}}")
      rescue TypeError => e #incorrect superclass error supression
        if e.message =~ /superclass mismatch/
          raise RUBYAMFException.new(RUBYAMFException.USER_ERROR, "An error occured when loading your application models, Your service is requiring another class of the same type of one of your models.")
        end
      rescue Exception => e
        raise RUBYAMFException.new(RUBYAMFException.USER_ERROR, "An error occured while loading your models. #{e.message}")
      end
    end
  end
end

#Invoke a service call on the loaded class (loads the class in the class_action)
class InvokeAction
	def run(amfbody)
	  if amfbody.exec == false
	    if amfbody.special_handling == 'Ping'
        amfbody.results = generate_acknowledge_object(amfbody.get_meta('messageId'), amfbody.get_meta('clientId')) #generate an empty acknowledge message here, no body needed for a ping
        #amfbody.resultsXML = generate_acknowledge_object(amfbody.get_meta('messageId'), amfbody.get_meta('clientId')) #generate an empty acknowledge message here, no body needed for a ping
        amfbody.success! #flag the success response
      end
      return
	  end
		@amfbody = amfbody #store amfbody in member var
		invoke
	end
  
	#invoke the service call
	def invoke
		begin
		  @service = Object.const_get(@amfbody.service_name).new #handle on service
		  RequestStore.available_services[@amfbody.service_name] = @service
		rescue LoadError => e
			raise RUBYAMFException.new(RUBYAMFException.LOAD_CLASS_FILE, "The file #{@amfbody.class_file_uri}#{@amfbody.class_file} was not loaded. Check to make sure it exists in: #{RequestStore.service_path}")
		rescue Exception => e
		  raise RUBYAMFException.new(RUBYAMFException.LOAD_CLASS_FILE, "There was an error loading file #{@amfbody.class_file_uri}#{@amfbody.class_file}. #{e.message}")
		end
    
    #authentication, simple
	  if RequestStore.auth_header != nil
	    if @service.public_methods.include?('_authenticate')
	      begin
  	      res = @service.send('_authenticate', *[RequestStore.auth_header.value.userid, RequestStore.auth_header.value.password])
          if res == false #catch false
      		  raise RUBYAMFException.new(RUBYAMFException.AUTHENTICATION_ERROR, "Authentication Failed");
          elsif res.class.to_s == 'FaultObject' #catch returned FaultObjects
      		  raise RUBYAMFException.new(res.code, res.message)
      		end
      	rescue Exception => e #catch raised FaultObjects
      	  if e.message == "exception class/object expected"
      	    raise RUBYAMFException.new(RUBYAMFException.USER_ERROR,"You cannot raise a FaultObject, return it instead.")
      	  else  
      	    raise RUBYAMFException.new(RUBYAMFException.USER_ERROR,e.message)
      	  end
      	end
    	end
	  end
    
    #before_filter
    if @service.public_methods.include?('before_filter')
	    begin
	      res = @service.send('before_filter')
  	    if res == false #catch false
  	      raise RUBYAMFException.new(RUBYAMFException.FILTER_CHAIN_HAULTED, "before_filter haulted by returning false.")
  	    elsif res.class.to_s == 'FaultObject' #catch returned FaultObjects
  	      raise RUBYAMFException.new(res.code, res.message)
  	    end
    	rescue Exception => e #catch raised FaultObjects
    	  if e.message == "exception class/object expected"
    	    raise RUBYAMFException.new(RUBYAMFException.USER_ERROR,"You cannot raise a FaultObject, return it instead.")
    	  else  
    	    raise RUBYAMFException.new(RUBYAMFException.USER_ERROR,e.message)
    	  end
    	end
	  end
	  
		if @service.private_methods.include?(@amfbody.service_method_name)
			raise RUBYAMFException.new(RUBYAMFException.METHOD_ACCESS_ERROR, "The method {#{@amfbody.service_method_name}} in class {#{@amfbody.class_file_uri}#{@amfbody.class_file}} is declared as private, it must be defined as public to access it.")
		elsif !@service.public_methods.include?(@amfbody.service_method_name)
			raise RUBYAMFException.new(RUBYAMFException.METHOD_UNDEFINED_METHOD_ERROR, "The method {#{@amfbody.service_method_name}} in class {#{@amfbody.class_file_uri}#{@amfbody.class_file}} is not declared.")
		end
		
		begin
			if @amfbody.value.empty?
				@service_result = @service.send(@amfbody.service_method_name)
			else
				args = @amfbody.value
				@service_result = @service.send(@amfbody.service_method_name, *args) #* splat the argument values to pass correctly to the service method
			end
		rescue Exception => e #catch any method call errors, transform into RUBYAMFException so that they propogate back to flash correctly
			if e.message == "exception class/object expected"
  	    raise RUBYAMFException.new(RUBYAMFException.USER_ERROR,"You cannot raise a FaultObject, return it instead.")
  	  else  
			  raise RUBYAMFException.new(RUBYAMFException.USER_ERROR, e.to_s)
			end
		end
		
		#catch returned custom FaultObjects
		if @service_result.class.to_s == 'FaultObject'
		  raise RUBYAMFException.new(@service_result.code, @service_result.message)
		end
			  
		@amfbody.results = @service_result #set the result in this body object
		#@amfbody.resultsXML = @service_result #set the result in this body object
				
		#amf3
    if @amfbody.special_handling == 'RemotingMessage'
      @wrapper = generate_acknowledge_object(@amfbody.get_meta('messageId'), @amfbody.get_meta('clientId'))
      @wrapper.body = @service_result
      @amfbody.results = @wrapper
		end
		
	  @amfbody.success! #set the success response uri flag (/onResult)		
	end
end

#Invoke ActionController's process on the target controller action
class RailsInvokeAction
  
	def run(amfbody)
	  if amfbody.exec == false
	    if amfbody.special_handling == 'Ping'
        amfbody.results = generate_acknowledge_object(amfbody.get_meta('messageId'), amfbody.get_meta('clientId')) #generate an empty acknowledge message here, no body needed for a ping
        #amfbody.resultsXML = generate_acknowledge_object(amfbody.get_meta('messageId'), amfbody.get_meta('clientId')) #generate an empty acknowledge message here, no body needed for a ping
        
	amfbody.success! #flag the success response
      end
      return
	  end
		@amfbody = amfbody #store amfbody in member var
		invoke
	end
  
	#invoke the service call
	def invoke
		begin
	    @service = Object.const_get(@amfbody.service_name).new #handle on service
	    RequestStore.available_services[@amfbody.service_name] = @service
		rescue LoadError => e
			raise RUBYAMFException.new(RUBYAMFException.LOAD_CLASS_FILE, "The file #{@amfbody.class_file_uri}#{@amfbody.class_file} was not loaded. Check to make sure it exists in: #{RequestStore.service_path}")
		rescue Exception => e
		  raise RUBYAMFException.new(RUBYAMFException.LOAD_CLASS_FILE, "There was an error loading file #{@amfbody.class_file_uri}#{@amfbody.class_file}.")
		end
		
		if @service.private_methods.include?(@amfbody.service_method_name)
			raise RUBYAMFException.new(RUBYAMFException.METHOD_ACCESS_ERROR, "The method {#{@amfbody.service_method_name}} in class {#{@amfbody.class_file_uri}#{@amfbody.class_file}} is declared as private, it must be defined as public to access it.")
		elsif !@service.public_methods.include?(@amfbody.service_method_name)
			raise RUBYAMFException.new(RUBYAMFException.METHOD_UNDEFINED_METHOD_ERROR, "The method {#{@amfbody.service_method_name}} in class {#{@amfbody.class_file_uri}#{@amfbody.class_file}} is not declared.")
		end
				
		#clone the request and response and alter it for the target controller/method
		req = RequestStore.rails_request.clone
		res = RequestStore.rails_response.clone
		
		#change the request controller/action targets and tell the service to process. THIS IS THE VOODOO. SWEET!
	  ct = @amfbody.target_uri.clone.split('Controller')[0].downcase
	  sm = @amfbody.service_method_name
		req.parameters['controller'] = ct
		req.parameters['action'] = sm
		req.request_parameters['controller'] = ct
		req.request_parameters['action'] = sm
		req.request_parameters['amf'] = 'hello world'
		req.path_parameters['controller'] = ct
		req.path_parameters['action'] = ct
		req.env['PATH_INFO'] = "#{ct}/#{sm}"
		req.env['REQUEST_PATH'] = "#{ct}/#{sm}"
		req.env['REQUEST_URI'] = "#{ct}/#{sm}"
		req.env['HTTP_ACCEPT'] = 'application/x-amf,' + req.env['HTTP_ACCEPT'].to_s
		
		#set conditional helper
		@service.is_amf = true
		@service.is_rubyamf = true
    
    #process the request
		if @amfbody.value.empty? || @amfbody.value.nil?
		  @service.process(req,res)
		else
		  @amfbody.value.each_with_index do |item,i|		    
		    req.parameters[i] = item
		    if item.class.superclass.to_s == 'ActiveRecord::Base'
		      req.parameters[i] = item.original_vo_from_deserialization.to_hash
          if i < 1 #Only the first parameter will be 
            req.parameters.merge!(item.original_vo_from_deserialization.to_hash) #merge in properties into the params hash
            #have to specifically check for id here, as it doesn't show up in any object members.
            if item.original_vo_from_deserialization.id != nil
              #This will override the above params[:id] attempt, because it's the original deserialized values.
              req.parameters[:id] = item.original_vo_from_deserialization.id
            end
          end
	        req.parameters[item.class.to_s.downcase.to_sym] = item.original_vo_from_deserialization.to_hash
	        
		    elsif !item._explicitType.nil?
		      t = item._explicitType
		      if t.include?('.')
		        t = t.split('.').last.downcase.to_s
		      end
  		    req.parameters[t.to_sym] = item.to_hash
  		    if i < 1
  		      if item.class.to_s == 'Object' || item.class.to_s == 'OpenStruct'
    		      if item.id != nil && item.id.to_s != 'NaN' && item.id != 0
    		        req.parameters[:id] = item.id
    		      end
    		    end
  		      req.parameters.merge!(item.to_hash)
  		    end
  		    
  		  elsif item.class.to_s == 'OpenStruct' || item.class.to_s == "Object"
		      if i < 1
  		      if item.id != nil && item.id.to_s != 'NaN' && item.id != 0
  		        req.parameters[:id] = item.id
  		      end
  		      req.parameters.merge!(item.to_hash)
  		    end  		    
		    end
      end
	    @service.process(req,res)
    end
    
    #unset conditional helper
    @service.is_amf = false
		@service.is_rubyamf = false
    
		#handle FaultObjects
		if @service.amf_content.class.to_s == 'FaultObject' #catch returned FaultObjects
      raise RUBYAMFException.new(@service.amf_content.code, @service.amf_content.message)
		end
		
		#amf3
		@amfbody.results = @service.amf_content
		#@amfbody.resultsXML = @service.amf_content
    if @amfbody.special_handling == 'RemotingMessage'
      @wrapper = generate_acknowledge_object(@amfbody.get_meta('messageId'), @amfbody.get_meta('clientId'))
      @wrapper.body = @service.amf_content
      @amfbody.results = @wrapper
		end
	  @amfbody.success! #set the success response uri flag (/onResult)
	end
end

#this class takes the amfobj's results (if a db result) and adapts it to a flash recordset
class ResultAdapterAction
  #include Adapters #include the module that defines what adapters to test for
  
	def run(amfbody)
	  #If you opted in for deep adaptation attempts don't do anything here, it will all be handled in the serializer
	  if Adapters.deep_adaptations
	    return
	  end
	  
    new_results = '' #for some reason this has to be initialized here.. not sure why
    resultsXML = ''
		if amfbody.special_handling == 'RemotingMessage'
		  results = amfbody.results.body
		else
		  results = amfbody.results
		end
    
    begin
      if adapter = Adapters.get_adapter_for_result(results)
        #new_results = adapter.run(results)
        adapter.run(results)
        new_results = adapter.get_results
	resultsXML = adapter.get_XML
      else
        return
      end
    rescue RUBYAMFException => ramfe
      raise ramfe
    rescue Exception => e
      ramfe = RUBYAMFException.new(e.class.to_s, e.message.to_s)
			ramfe.ebacktrace = e.backtrace.to_s
			raise ramfe
    end
    
		if amfbody.special_handling == 'RemotingMessage'
		  amfbody.results.body = new_results
	  else
	    amfbody.results = new_results
            amfbody.rexultsXML = resultsXML
	  end
	end
end

def generate_acknowledge_object(message_id = nil, client_id = nil)
  res = OpenStruct.new
	res._explicitType = "flex.messaging.messages.AcknowledgeMessage"
  res.messageId = rand_uuid
  if client_id == nil
    res.clientId = rand_uuid
  else
    res.clientId = client_id
  end
  res.destination = nil
  res.body = nil
  res.timeToLive = 0
  res.timestamp = (String(Time.new) + '00')
  res.headers = {}
  res.correlationId = message_id
  return res
end

#going for speed with these UUID's not neccessarily unique in space and time continue - um, word
def rand_uuid
  [8,4,4,4,12].map {|n| rand_hex_3(n)}.join('-').to_s
end

def rand_hex_3(l)
  "%0#{l}x" % rand(1 << l*4)
end
end
end
