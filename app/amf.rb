require 'exception/rubyamf_exception'
module RubyAMF
module AMF
include RubyAMF::VoHelper
#A High level amf message wrapper with methods for easy header and body manipulation
class AMFObject

  #raw input stream
  attr_accessor :input_stream
  
  #serialized output stream
  attr_accessor :output_stream
  
  attr_accessor :bodys
    
  #create a new AMFObject, pass the raw request data
  def initialize(rw = nil)
    @input_stream = rw
    @output_stream = "" #BinaryString.new("")
    @inheaders = Array.new
    @outheaders = Array.new
    @bodys = Array.new
    @header_table = Hash.new
  end

  #add a raw header to this amf_object
  def add_header(amf_header)
    @inheaders << amf_header
    @header_table[amf_header.name] = amf_header
  end

  #get a header by it's key
  def get_header_by_key(key)
    @header_table[key]||false
  end

  #get a header at a specific index
  def get_header_at(i=0)
    @inheaders[i]||false
  end

  #get the number of in headers
  def num_headers
    @inheaders.length
  end

  #add a parse header to the outgoing pool of headers
  def add_outheader(amf_header)
    @outheaders << amf_header
  end

  #get a header at a specific index
  def get_outheader_at(i=0)
    @outheaders[i]||false
  end

  #get all the in headers
  def get_outheaders
    @outheaders
  end

  #Get the number of out headers
  def num_outheaders
    @outheaders.length
  end

  #add a body
  def add_body(amf_body)
    @bodys << amf_body
  end

  #get a body obj at index
  def get_body_at(i=0)
    @bodys[i]||false
  end

  #get the number of bodies
  def num_body
    @bodys.length
  end

  #add a body to the body pool at index
  def add_body_at(index,body)
    @bodys.insert(index,body)
  end
  
  #add a body to the top of the array
  def add_body_top(body)
    @bodys.unshift(body)
  end

  #Remove a body from the body pool at index
  def remove_body_at(index)
    @bodys.delete_at(index)
  end
  
  #remove the AUTH header, (it is always at the top)
  def remove_auth_body
    @bodys.shift
  end
  
  #remove all bodies except the auth body
  def only_auth_fail_body!
    auth_body = nil
    @bodys.each do |b|
      if b.inspect.to_s.match(/Authentication Failed/) != 
        auth_body = b
      end
    end
    @bodys = [auth_body] if auth_body
  end
end
# Wraps an amfbody with methods and params for easter manipulation
class AMFBody

  include RubyAMF::Exceptions
  include RubyAMF::App
  
  attr_accessor :id             #the amfbody id
  attr_accessor :response_index #the response unique index that the player understands, knows which result / fault methods to call.
  attr_accessor :response_uri   #the complete response uri (EX: /12/onStatus)  
  attr_accessor :target_uri     #the target uri (service name)  
  attr_accessor :service_class_file_path   #the service file path
  attr_accessor :service_class_name        #the service name  
  attr_accessor :service_method_name       #the service method name
  attr_accessor :value          #the parameters to use in the service call 
  attr_accessor :results        #the results from a service call  
  attr_accessor :special_handling     #special handling
  attr_accessor :exec           #executeable body
  attr_accessor :_explicitType  #set the explicit type

  #create a new amfbody object
  def initialize(target = "", response_index = "", value = "")
    @id = response_index.clone.split('/').to_s
    @target_uri = target
    @response_index = response_index
    @response_uri = @response_index + '/onStatus' #default to status call
    @value = value
    @exec = true
    @_explicitType = ""
    @meta = {}
  end
    
  #append string data the the response uri
  def append_to_response_uri(str)
    @response_uri = @response_uri + str
  end
  
  #set some meta data for this amfbody
  def set_meta(key,val)
    @meta[key] = val
  end
  
  #get the meta data by key
  def get_meta(key)
    @meta[key]
  end
  
  #trigger an update to the response_uri to be a successfull response (/1/onResult)
  def success!
    @response_uri = "#{@response_index}/onResult"
  end
  
  #force the call to fail in the flash player
  def fail!
    @response_uri = "#{@response_index}/onStatus"
  end
  
  # allows a target_uri of "services.[bB]ooks", "services.[bB]ooksController to become service_class_name "Services::BooksController" and the class file path to be "services/books_controller.rb" 
  def set_service_uri_information!
    if @target_uri 
      uri_elements =  @target_uri.split(".") 
      @service_method_name ||= uri_elements.pop # this was already set, probably amf3, that means the target_uri doesn't include it
      if !uri_elements.empty?
        uri_elements.last << "Controller" unless uri_elements.last.include?("Controller")
        @service_class_name      = uri_elements.collect(&:to_title).join("::")
        @service_class_file_path = "#{RequestStore.service_path}/#{uri_elements[0..-2].collect{|x| x+'/'}}#{uri_elements.last.underscore}.rb"
      else
        raise RUBYAMFException.new(RUBYAMFException.SERVICE_TRANSLATION_ERROR, "The correct service information was not provided to complete the service call. The service and method name were not provided")
      end
    else
      if RequestStore.flex_messaging
        raise RUBYAMFException.new(RUBYAMFException.USER_ERROR, "There is no \"source\" property defined on your RemoteObject, please see RemoteObject documentation for more information.")
      else
        raise RUBYAMFException.new(RUBYAMFException.SERVICE_TRANSLATION_ERROR, "The correct service information was not provided to complete the service call. The service and method name were not provided")
      end
    end
  end
  
end

#a simple wrapper class that wraps an amfheader
class AMFHeader
  attr_accessor :name, :value, :required
  def initialize(name,required,value)
    @name, @value, @required = name, value, required
  end
end 
   
#this cass takes a RUBYAMFException and inspects the details of the exception, returning this object back to flash as a Fault object
class ASFault < VoHash
  
  #pass a RUBYAMFException, create new keys based on exception for the fault object
  def initialize(e)
        
    backtrace = e.backtrace || e.ebacktrace #grab the correct backtrace
    
    begin
      linerx = /:(\d*):/
      line = linerx.match(backtrace[0])[1] #get the numbers
    rescue Exception => e
      line = 'No backtrace was found in this exception'
    end
    
    begin
      methodrx = /`(\S*)\'/
      method = methodrx.match(backtrace[0])[1] #just method name
    rescue Exception => e
      method = "No method was found in this exception"
    end
    
    begin
      classrx = /([a-zA-Z0-9_]*)\.rb/
      classm = classrx.match(backtrace[0]) #class name
    rescue Exception => e
      classm = "No class was found in this exception"
    end
    
    self["code"] = e.etype.to_s #e.type.to_s
    self["description"] = e.message
    self["details"] = backtrace[0]
    self["level"] = 'UserError'
    self["class_file"] = classm.to_s
    self["line"] = line
    self["function"] = method
    self["faultString"] = e.message
    self["faultCode"] = e.etype.to_s
    self["backtrace"] = backtrace
  end
end

#ActionScript 3 Exeption, this class bubbles to the player after an Exception in Ruby
class AS3Fault < VoHash
  
  #  attr_accessor :faultCode, :faultString, :faultDetail, :rootCause, :extendedData
  #pass a RUBYAMFException, create new keys based on exception for the fault object
  def initialize(e)
    backtrace = e.backtrace || e.ebacktrace #grab the correct backtrace    
    self._explicitType = 'flex.messaging.messages.ErrorMessage'
    self["faultCode"] = e.etype.to_s #e.type.to_s
    self["faultString"] = e.message
    self["faultDetail"] = backtrace
    self["rootCause"] = backtrace[0]
    self["extendedData"] = backtrace
  end
end

# Simple wrapper for serizlization time. All adapters adapt the db result into an ASRecordset, 
class ASRecordset
  
  #accessible attributes for this asrecordset
  attr_accessor :total_count
  
  #the number of rows in the recordset
  attr_accessor :row_count
  
  #columns returned
  attr_accessor :column_names
  
  #the payload for a recordset
  attr_accessor :initial_data
  
  #cursor position
  attr_accessor :cursor
  
  #id of the recoredset
  attr_accessor :id
  
  #version of the recordset
  attr_accessor :version
  
  #the service name that was originally called
  attr_accessor :service_class_name
  
  #this is an optional argument., a database adapter could optionally serialize the results, instead of the AMFSerializer serializing the results
  attr_accessor :serialized_data
  
  #mark this recordset as pageable
  attr_accessor :is_pageable

  #new ASRecordset
  def initialize(row_count,column_names,initial_data)
    self.row_count = row_count
    self.column_names = column_names
    self.initial_data = initial_data
    cursor = 1
    version = 1
  end
end

end
end