require 'ostruct'
require 'exception/rubyamf_exception'
include RUBYAMF::Exceptions

#AMF0
AMF_NUMBER = 0x00
AMF_BOOLEAN = 0x01
AMF_STRING = 0x02
AMF_OBJECT = 0x03
AMF_MOVIE_CLIP = 0x04
AMF_NULL = 0x05
AMF_UNDEFINED = 0x06
AMF_REFERENCE = 0x07
AMF_MIXED_ARRAY = 0x08
AMF_EOO = 0x09
AMF_ARRAY = 0x0A
AMF_DATE = 0x0B
AMF_LONG_STRING = 0x0C
AMF_UNSUPPORTED = 0x0D
AMF_RECORDSET = 0x0E
AMF_XML = 0x0F
AMF_TYPED_OBJECT = 0x10

#AMF3
AMF3_TYPE = 0x11
AMF3_UNDEFINED = 0x00
AMF3_NULL = 0x01
AMF3_FALSE = 0x02
AMF3_TRUE = 0x03
AMF3_INTEGER = 0x04
AMF3_NUMBER = 0x05
AMF3_STRING = 0x06
AMF3_XML = 0x07
AMF3_DATE = 0x08
AMF3_ARRAY = 0x09
AMF3_OBJECT = 0x0A
AMF3_XML_STRING = 0x0B
AMF3_BYTE_ARRAY = 0x0C
AMF3_INTEGER_MAX = 268435455
AMF3_INTEGER_MIN = -268435456

module RUBYAMF
module AMF

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
		if @header_table[key] != nil
			return @header_table[key]
		end
		return false
	end

	#get a header at a specific index
	def get_header_at(i=0)
		if @inheaders[i] != nil
			return @inheaders[i]
		end
		return false
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
		if @outheaders[i] != nil
			return @outheaders[i]
		end
		return false
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
		if @bodys[i]
			return @bodys[i]
		end
		return false
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
	  if auth_body != nil then @bodys = [auth_body] end
	end
end

# Wraps an amfbody with methods and params for easter manipulation
class AMFBody
	
	#the amfbody id
	attr_accessor :id
		
	#the response unique index that the player understands, knows which result / fault methods to call.
	attr_accessor :response_index
  
	#the complete response uri (EX: /12/onStatus)
	attr_accessor :response_uri
	
	#the target uri (service name)
	attr_accessor :target_uri
	
	#the class name where the service mthod resides
	attr_accessor :class_file
	
	#the uri to the class file
	attr_accessor :class_file_uri
	
	#the service name
	attr_accessor :service_name
	
	#the service method name
	attr_accessor :service_method_name
	
	#the parameters to use in the service call
	attr_accessor :value
  
	#the results from a service call
	attr_accessor :results
	
	#special handling
	attr_accessor :special_handling
	
	#executeable body
	attr_accessor :exec
	
	#set the explicit type
	attr_accessor :_explicitType

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
		
	#set the service name and the method to call
	def set_amf0_service_and_method
		if @target_uri.include?('.')
			nw = @target_uri.clone.split('.')
			@service_method_name = nw.pop
			@service_name = nw.last
		else
			raise RUBYAMFException.new(RUBYAMFException.SERVICE_TRANSLATION_ERROR, "The correct service information was not provided to complete the service call. The service and method name were not provided")
		end
	end
	
	#set the file that holds the service call to use
	def set_amf0_class_file_and_uri
		if @target_uri.include?('.')
			nw = @target_uri.clone.split('.')
			nw.pop #just pop out the method name, not needed here
			@class_file = nw.last.clone << '.rb'
			nw.pop #pop out the service name now, to create the file URI
			@class_file_uri = nw.join('/') + '/'
		else
			raise RUBYAMFException.new(RUBYAMFException.SERVICE_TRANSLATION_ERROR, "The correct service information was not provided to complete the service call. The service and method name were not provided")
		end
	end
	
	#set class file uri for amf3
	def set_amf3_class_file_and_uri
		#Catch missing source property on RemoteObject
		if @target_uri.nil?
		  if RequestStore.flex_messaging
		    raise RUBYAMFException.new(RUBYAMFException.USER_ERROR, "There is no \"source\" property defined on your RemoteObject, please see RemoteObject documentation for more information.")
		  else
		    raise RUBYAMFException.new(RUBYAMFException.SERVICE_TRANSLATION_ERROR, "The correct service information was not provided to complete the service call. The service and method name were not provided")
		  end
		end
	  if @target_uri.include?('.')
			nw = @target_uri.clone.split('.')
			@service_name = nw.last.clone
			@class_file = nw.last.clone << '.rb'
			nw.pop #pop out the service name now, to create the file URI
			@class_file_uri = nw.join('/') + '/'
		else
		  @service_name = @target_uri
		  @class_file = @target_uri + '.rb'
      @class_file_uri = '/'
		end
	end
end

#a simple wrapper class that wraps an amfheader
class AMFHeader
	attr_accessor :name
	attr_accessor :value
	attr_accessor :required
	def initialize(key,required,value)
		@name = key
		@required = required
		@value = value
	end
end 
   
#this cass takes a RUBYAMFException and inspects the details of the exception, returning this object back to flash as a Fault object
class ASFault < OpenStruct
	
	#pass a RUBYAMFException, create new keys based on exception for the fault object
	def initialize(e)
		super(nil)
				
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
		
		self.code = e.etype.to_s #e.type.to_s
		self.description = e.message
		self.details = backtrace[0]
		self.level = 'UserError'
		self.class_file = classm.to_s
		self.line = line
		self.function = method
		self.faultString = e.message
		self.faultCode = e.etype.to_s
		self.backtrace = backtrace
	end
end

#ActionScript 3 Exeption, this class bubbles to the player after an Exception in Ruby
class AS3Fault < OpenStruct
  
  #pass a RUBYAMFException, create new keys based on exception for the fault object
	def initialize(e)
		super(nil)
		backtrace = e.backtrace || e.ebacktrace #grab the correct backtrace		
    self._explicitType = 'flex.messaging.messages.ErrorMessage'
		self.faultCode = e.etype.to_s #e.type.to_s
		self.faultString = e.message
		self.faultDetail = backtrace
		self.rootCause = backtrace[0]
    self.extendedData = backtrace
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
	attr_accessor :service_name
	
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

#AS3 DataProvider holder, this is used for Straight Flash 9 DataProviders (not Flex 2 ArrayCollections)
class AS3DataProvider
  attr_accessor :data
  def initialize(data)
    self.data = data
  end
end

end
end