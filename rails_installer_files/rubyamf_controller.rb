RUBYAMF_ROOT = File.expand_path(RAILS_ROOT) + '/vendor/plugins/rubyamf/'
RUBYAMF_CORE = File.expand_path(RAILS_ROOT) + '/vendor/plugins/rubyamf/'
RUBYAMF_SERVICES = File.expand_path(RAILS_ROOT) + '/app/controllers'
RUBYAMF_HELPERS = File.expand_path(RAILS_ROOT) + '/vendor/plugins/rubyamf/helpers/'
$:.unshift(RUBYAMF_CORE)

require 'app/rails_gateway'
require 'app/request_store'
require 'util/log'

include RUBYAMF::App
include RUBYAMF::Util

class RubyamfController < ActionController::Base
  def gateway
	  	  
	  #this only catches exceptions in this scope, all other exceptions raise in the RubyAMF process get caught in the BatchFilter
	  #and are transformed into an exceptable Flash/Flex Fault object
	  begin 
  	  #this has to be set as the very first thing, as trying to change the logger to use a log file after it's been initialized fails
  	  Log.SetLogFile(RUBYAMF_CORE + '/logs/rubyamf.log')
  	  @log = Log.instance #init the logger, set level below
   		RequestStore.reload_services = false
   		
  		#create a new rubyamf gateway for processing
  		gateway = RailsGateway.new
  		
  		#clear auth hash
  		RequestStore.rails_authentication = {}
  		RequestStore.rails_request = request
  		RequestStore.rails_response = response
  		
		  #set the services path relative to this gateway.servlet file
  		gateway.services_path = RUBYAMF_SERVICES
  		gateway.config_path = File.expand_path(RAILS_ROOT) + "/config/rubyamf/"
		  
  		#default log level (debug, info, warn, error, fatal, none)
  		gateway.log_level = 'none'
		  
  		#see an exceptions backtrace in the fault object / netconnection debugger (comes in in the faultObject.backtrace property)
  		gateway.backtrace_on_error = false
		  
  		#turn on or off NetDebug functionality
  		#use NetDebug.Trace(msg) in a service method. (Works with AMF0 only)
  		gateway.allow_net_debug = false
			
			#if your using Flash 9 with Flash Remoting the format needs to be 'fl9'
			#if your useing Flash 8 with Flash Remogin the format needs to be 'fl8'
			#Flex FDS RemoteObject is handled nativly. No need to adjust the format for that.
			gateway.recordset_format = 'fl9' #OR 'fl8'
			#Note: You can use netConnection.addHeader to change this from Flash instead.
			#service.addHeader('recordset_format',false,'fl9');
			#service.addHeader('recordset_format',false,'fl8')
      #Read more about why this has to be specifically set at wiki.rubyamf.org/wiki/show/RecordSetFormat
			
			#Compress the amf output for smaller data transfer over the wire
			if(request.env['ACCEPT_ENCODING'].to_s.match(/gzip,[\s]{0,1}deflate/))
			  gateway.gzip_outgoing = true
			end
			
  	  #if not flash user agent, send some html content
  		if request.env['CONTENT_TYPE'].to_s.match(/x-amf/) == nil
  		  amf_response = "<html><head><title>RubyAMF Gateway</title>
  		  <style>body{margin:0;padding:0;font:12px sans-serif;color:#c8c8c8}td{font:12px sans-serif}</style>
  		  </head><body bgcolor='#222222'>
  		  <table width='100%' align=center valign=middle height='100%'>
  		  <tr><td width=100 align=center>
  		  <a href='http://blog.rubyamf.org'><img border=0 src='http://blog.rubyamf.org/images/gateway.png' /></a>"
  		else
  		  #send the raw data throught the rubyamf gateway and create the response
		    amf_response = gateway.service(request.env["RAW_POST_DATA"])
  		  headers['Content-Type'] = "application/x-amf"
  		end
  		  		
      #render the AMF
      render :text => amf_response
	  rescue Exception => e #only errors in this scope will ever be rescued here, see BatchFiler
      STDOUT.puts e.to_s
	    STDOUT.puts e.backtrace
	  end
  end
  
  
  def rescue_action(e)
    #There are a couple things that will trigger this rescue_action. Which aren't
    #ever returned to the flash player. be ware. but I will put a fix for this in.
    puts "/rubyamf/gateway/render_action"
    puts e.message
    puts e.backtrace
  end
  
end