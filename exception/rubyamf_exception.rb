module RubyAMF
module Exceptions

#Encompasses all rubyamf specific exceptions that occur
class RUBYAMFException < Exception
  
  #when version is not 0 or 3
  @VERSION_ERROR = 'RUBYAMF_AMF_VERSION_ERROR'
  
  #when translating the target_uri of a body, there isn't a .(period) to map the service / method name
  @SERVICE_TRANSLATION_ERROR = 'RUBYAMF_SERVICE_TRANSLATION_ERROR'
  
  #when an authentication error occurs
  @AUTHENTICATION_ERROR = 'RUBYAMF_ATUHENTICATION_ERROR'
  
  #when a method is called, but the method is either private or doesn't exist
  @METHOD_ACCESS_ERROR = 'RUBYAMF_METHOD_ACCESS_ERROR'
  
  #when a mehod is undefined
  @METHOD_UNDEFINED_METHOD_ERROR = 'RUBYAMF_UNDECLARED_METHOD_ERROR'
  
  #when there is an error with session implementation
  @SESSION_ERROR = 'RUBYAMF_SESSION_ERROR'
  
  #when a general user error has occured
  @USER_ERROR = 'RUBYAMF_USER_ERROR'
  
  #when parsing AMF3, an undefined object reference
  @UNDEFINED_OBJECT_REFERENCE_ERROR = 'RUBYAMF_UNDEFINED_OBJECT_REFERENCE_ERROR'
  
  #when parsing AMF3, an undefined class definition
  @UNDEFINED_DEFINITION_REFERENCE_ERROR = 'RUBYAMF_UNDEFINED_DEFINIITON_REFERENCE_ERROR'
  
  #when parsing amf3, an undefined string reference
  @UNDEFINED_STRING_REFERENCE_ERROR = 'RUBYAMF_UNDEFINED_STRING_REFERENCE_ERROR'
  
  #unsupported AMF0 type
  @UNSUPPORTED_AMF0_TYPE = 'UNSUPPORTED_AMF0_TYPE'
  
  #when the Rails ActionController Filter chain haults
  @FILTER_CHAIN_HAULTED = 'RAILS_ACTION_CONTROLLER_FILTER_CHAIN_HAULTED'
  
  #when active record errors
  @ACTIVE_RECORD_ERRORS = 'ACTIVE_RECORD_ERRORS'
  
  #whan amf data is incomplete or incorrect
  @AMF_ERROR = 'AMF_ERROR'
  
  #vo errors
  @VO_ERROR = 'VO_ERROR'
  
  #when a parameter mapping error occurs
  @PARAMETER_MAPPING_ERROR = "PARAMETER_MAPPING_ERROR"
  
  attr_accessor :message
  attr_accessor :etype
  attr_accessor :ebacktrace
  attr_accessor :payload
  
  #static accessors
  class << self
    attr_accessor :VERSION_ERROR
    attr_accessor :SERVICE_TRANSLATION_ERROR
    attr_accessor :AUTHENTICATION_ERROR
    attr_accessor :METHOD_ACCESS_ERROR
    attr_accessor :METHOD_UNDEFINED_METHOD_ERROR
    attr_accessor :SESSION_ERROR
    attr_accessor :USER_ERROR
    attr_accessor :UNDEFINED_OBJECT_REFERENCE_ERROR
    attr_accessor :UNDEFINED_DEFINITION_REFERENCE_ERROR
    attr_accessor :UNDEFINED_STRING_REFERENCE_ERROR
    attr_accessor :UNSUPPORTED_TYPE
    attr_accessor :ADAPTER_ERROR
    attr_accessor :INTERNAL_ERROR
    attr_accessor :UNSUPPORTED_AMF0_TYPE
    attr_accessor :FILTER_CHAIN_HAULTED
    attr_accessor :ACTIVE_RECORD_ERRORS
    attr_accessor :VO_ERROR
    attr_accessor :AMF_ERROR
    attr_accessor :PARAMETER_MAPPING_ERROR
  end
  
  def initialize(type,msg)
    super(msg)
    @message = msg
    @etype = type
  end
  
  # stringify the message
  def to_s
    @msg
  end
  
end
end
end
