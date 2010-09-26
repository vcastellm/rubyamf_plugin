RUBY_19 = "1.9.0"
RUBY_18 = "1.8.4"

require 'app/configuration'
module RubyAMF
  module Actions
    module Utils
      include RubyAMF::VoHelper
      
      def generate_acknowledge_object(message_id = nil, client_id = nil)
        res = VoHash.new
        res._explicitType = "flex.messaging.messages.AcknowledgeMessage"
        res["messageId"] = rand_uuid
        res["clientId"] = client_id||rand_uuid
        res["destination"] = nil
        res["body"] = nil
        res["timeToLive"] = 0
        res["timestamp"] = (String(Time.new) + '00')
        res["headers"] = {}
        res["correlationId"] = message_id
        res
      end
      
      #going for speed with these UUID's not neccessarily unique in space and time continue - um, word
      def rand_uuid
        [8,4,4,4,12].map {|n| rand_hex_3(n)}.join('-').to_s
      end
      
      def rand_hex_3(l)
        "%0#{l}x" % rand(1 << l*4)
      end
    end
    #This sets up each body for processing
    class PrepareAction
      include RubyAMF::App
      include RubyAMF::Actions::Utils
      include RubyAMF::Configuration
      
      def run(amfbody)
        if RequestStore.amf_encoding == 'amf3'  && #AMF3
          (raw_body = amfbody.value[0]).is_a?(VoHash) &&
            ['flex.messaging.messages.RemotingMessage','flex.messaging.messages.CommandMessage'].include?(raw_body._explicitType)
          case raw_body._explicitType
          when 'flex.messaging.messages.RemotingMessage' #Flex Messaging setup
            RequestStore.flex_messaging = true # only set RequestStore and ClassMappings when its a remoting message, not command message
            ClassMappings.use_array_collection = !(ClassMappings.use_array_collection==false) # it will only set it to false if the user specifically sets use_array_collection to false
            amfbody.special_handling = 'RemotingMessage'
            amfbody.value = raw_body['body']
            amfbody.set_meta('clientId', raw_body['clientId'])
            amfbody.set_meta('messageId', raw_body['messageId'])
            amfbody.target_uri = raw_body['source']
            amfbody.service_method_name = raw_body['operation']
            amfbody._explicitType = raw_body._explicitType
          when 'flex.messaging.messages.CommandMessage' #it's a ping, don't process this body, and hence, dont set service uri information
            if raw_body['operation'] == 5
              amfbody.exec = false
              amfbody.special_handling = 'Ping'
              amfbody.set_meta('clientId', raw_body['clientId'])
              amfbody.set_meta('messageId', raw_body['messageId'])
            end
            return # we don't want it to run set_service_uri_information
          end
        else
          RequestStore.flex_messaging = false # ensure that array_collection is disabled 
          ClassMappings.use_array_collection = false
        end
        
        amfbody.set_service_uri_information!
      end  
    end
    
    #Invoke ActionController's process on the target controller action
    class RailsInvokeAction
      include RubyAMF::App
      include RubyAMF::Exceptions
      include RubyAMF::Configuration
      include RubyAMF::Actions::Utils
      include RubyAMF::VoHelper
      
      def run(amfbody)
        if amfbody.exec == false
          if amfbody.special_handling == 'Ping'
            amfbody.results = generate_acknowledge_object(amfbody.get_meta('messageId'), amfbody.get_meta('clientId')) #generate an empty acknowledge message here, no body needed for a ping
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
          # RequestStore.available_services[@amfbody.service_class_name] ||=
          @service =  @amfbody.service_class_name.constantize.new #handle on service
        rescue Exception => e
          puts e.message
          puts e.backtrace
          raise RUBYAMFException.new(RUBYAMFException.UNDEFINED_OBJECT_REFERENCE_ERROR, "There was an error loading the service class #{@amfbody.service_class_name}")
        end
        
        #call one or the other method depending in the ruby version we are using
        if RUBY_VERSION > RUBY_19
          caller = "to_sym"
        else
          caller = "to_s"
        end 

        if @service.private_methods.include?(@amfbody.service_method_name.send(caller))
          raise RUBYAMFException.new(RUBYAMFException.METHOD_ACCESS_ERROR, "The method {#{@amfbody.service_method_name}} in class {#{@amfbody.service_class_file_path}} is declared as private, it must be defined as public to access it.")
        elsif !@service.public_methods.include?(@amfbody.service_method_name.send(caller))
          raise RUBYAMFException.new(RUBYAMFException.METHOD_UNDEFINED_METHOD_ERROR, "The method {#{@amfbody.service_method_name}} in class {#{@amfbody.service_class_file_path}} is not declared.")
        end
        
        #clone the request and response and alter it for the target controller/method
        req = RequestStore.rails_request.clone
        res = RequestStore.rails_response.clone
        
        #change the request controller/action targets and tell the service to process. THIS IS THE VOODOO. SWEET!
        controller = @amfbody.service_class_name.gsub("Controller","").underscore
        action     = @amfbody.service_method_name
        req.parameters['controller'] = req.request_parameters['controller'] = req.path_parameters['controller'] = controller
        req.parameters['action']     = req.request_parameters['action']     = req.path_parameters['action']     = action
        req.env['PATH_INFO']         = req.env['REQUEST_PATH']              = req.env['REQUEST_URI']            = "#{controller}/#{action}"
        req.env['HTTP_ACCEPT'] = 'application/x-amf,' + req.env['HTTP_ACCEPT'].to_s
        
        #set conditional helper
        @service.is_amf = true
        @service.is_rubyamf = true
        
        #process the request
        rubyamf_params = @service.rubyamf_params = {}
        if @amfbody.value && !@amfbody.value.empty?
          @amfbody.value.each_with_index do |item,i|
            rubyamf_params[i] = item
          end
        end
        
        # put them by default into the parameter hash if they opt for it
        rubyamf_params.each{|k,v| req.parameters[k] = v} if ParameterMappings.always_add_to_params       
          
        begin
          #One last update of the parameters hash, this will map custom mappings to the hash, and will override any conflicting from above
          ParameterMappings.update_request_parameters(@amfbody.service_class_name, @amfbody.service_method_name, req.parameters, rubyamf_params, @amfbody.value)
        rescue Exception => e
          raise RUBYAMFException.new(RUBYAMFException.PARAMETER_MAPPING_ERROR, "There was an error with your parameter mappings: {#{e.message}}")
        end

        #fosrias
        #@service.process(req, res)

        # call the controller action differently depending on Rails version
        if Rails::VERSION::MAJOR < 3
          @service.process(req, res)
        else
          @service.request = req
          @service.response = res
          @service.process(action.to_sym)
        end
        #fosrias
        
        #unset conditional helper
        @service.is_amf = false
        @service.is_rubyamf = false
        @service.rubyamf_params = rubyamf_params # add the rubyamf_args into the controller to be accessed
        
        result = RequestStore.render_amf_results
        
        #handle FaultObjects
        if result.class.to_s == 'FaultObject' #catch returned FaultObjects - use this check so we don't have to include the fault object module
          e = RUBYAMFException.new(result['code'], result['message'])
          e.payload = result['payload']
          raise e
        end
        
        #amf3
        @amfbody.results = result
        if @amfbody.special_handling == 'RemotingMessage'
          @wrapper = generate_acknowledge_object(@amfbody.get_meta('messageId'), @amfbody.get_meta('clientId'))
          @wrapper["body"] = result
          @amfbody.results = @wrapper
        end
        @amfbody.success! #set the success response uri flag (/onResult)
      end
    end
  end
end
