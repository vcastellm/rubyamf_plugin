require 'app/gateway'
require 'ostruct'
require 'util/object'
require 'util/openstruct'
require 'util/active_record'
require 'util/action_controller'
require 'app/request_store'
require 'app/amf'
require 'exception/exception_handler'
require 'app/actions'
require 'app/filters'
require 'util/log'
require 'util/net_debug'
require 'logger'
require 'zlib'
include RUBYAMF::Actions
include RUBYAMF::App
include RUBYAMF::AMF
include RUBYAMF::Filter
include RUBYAMF::Exceptions
include RUBYAMF::Util

module RUBYAMF
module App

#Rails Gateway, extends regular gateway and changes the actions
class RailsGateway < Gateway
  
	def initialize
    super
		RequestStore.actions = Array[PrepareAction.new, ClassAction.new, RailsInvokeAction.new, ResultAdapterAction.new] #override the actions 
		RequestStore.rails = true
	end
		
private
	#This just requires the config file so that that configuration code runs
	def app_config
	  begin
	    require RequestStore.config_path + 'vo_config'
	    require RequestStore.config_path + 'adapters_config'
	  rescue Exception => e
	    STDOUT.puts "You have an error in your rubyamf_config file, please correct it."
	    STDOUT.puts e.message
	    STDOUT.puts e.backtrace
	  end
  end
end
end
end