require 'app/request_store'
require 'app/amf'
require 'app/actions'
require 'app/filters'
require 'app/configuration'
require 'exception/exception_handler'
require 'ostruct'
require 'util/object'
require 'util/openstruct'
require 'util/string'
require 'util/log'
require 'util/net_debug'
require 'util/active_record'
require 'util/bigdecimal'
require 'logger'
require 'zlib'
include RUBYAMF::Actions
include RUBYAMF::App
include RUBYAMF::AMF
include RUBYAMF::Configuration
include RUBYAMF::Filter
include RUBYAMF::Exceptions
include RUBYAMF::Util

module RUBYAMF
module App

#the rubyamf gateway. all requests circulate through this classes service method
class Gateway
	
	#creates a new gateway instance
	def initialize
	  @log = Log.instance
	  nd = NetDebug.new #new instance is made here so that if NetDebug isn't in the filter chain, it doesn't cause errors when trying to use it in a service method
		RequestStore.gateway_path = File.dirname(__FILE__) + './'
		RequestStore.actions_path = File.dirname(__FILE__) + '/actions/'
		RequestStore.filters_path = File.dirname(__FILE__) + '/filter/'
		RequestStore.adapters_path = File.dirname(__FILE__) + '/../adapters/'
		RequestStore.logs_path = File.dirname(__FILE__) + '/../logs/'
		RequestStore.actions = Array[PrepareAction.new, ClassAction.new, ApplictionInstanceInitAction.new, InvokeAction.new, ResultAdapterAction.new] #create the actions  
		RequestStore.filters = Array[AMFDeserializerFilter.new, RecordsetFormatFilter.new, AuthenticationFilter.new, BatchFilter.new, nd, AMFSerializeFilter.new] #create the filter
	end
	
	#all get and post requests circulate throught his method
	def service(raw)
	  app_config #run configuration scripts
		amfobj = AMFObject.new(raw)
		filter_chain = FilterChain.new
		filter_chain.run(amfobj)
		if RequestStore.gzip
		  return Zlib::Deflate.deflate(amfobj.output_stream)
		else
		  return amfobj.output_stream
		end
	end
	
	#Set the services path, relative to the gateway implementation your using(servlet or cgi file)
	def services_path=(path)
		RequestStore.service_path = path
	end
	
	def set_vo_path=(path)
	  RequestStore.vo_path = path
	end
	
	#turn on and off the NetDebug functionality
	def allow_net_debug=(val)
	  RequestStore.net_debug = val
	end
	
	#set the config path
	def config_path=(val)
	  RequestStore.config_path = val
	end
	
	def recordset_format=(val)
	  RequestStore.recordset_format = val
	end
	
	#whether or not to put the Exception#backtrace in the returned error object
	def backtrace_on_error=(val)
		RequestStore.use_backtraces = val
	end
	
	def gzip_outgoing=(val)
	  RequestStore.gzip = val
	end
	
	#set a log file, all development logging will go to this file, must be relative to THIS gateway file
	def set_log_file(filename)
	  @logfile = RequestStore.LOGS_PATH + filename
	end
	
	#set the logger level
	def log_level=(level)
	  if level == 'debug'
			@log.level = Logger::DEBUG
		elsif level == 'info'
			@log.level = Logger::INFO
		elsif level == 'warn'
			@log.level = Logger::WARN
		elsif level == 'error'
			@log.level = Logger::ERROR
		elsif level == 'fatal'
			@log.level = Logger::FATAL
		end
	end

private
	#This just requires the config file so that that configuration code runs
	def app_config
	  begin
	    require RequestStore.config_path + 'vo_config'
	    require RequestStore.config_path + 'adapters_config'
	    require RequestStore.config_path + 'application_instance_config'
	  rescue Exception => e
	    STDOUT.puts "You have an error in your rubyamf_config file, please correct it."
	    STDOUT.puts e.message
	    STDOUT.puts e.backtrace
	  end
  end
  
end
end
end