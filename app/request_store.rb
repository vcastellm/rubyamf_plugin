module RUBYAMF
module App

#store information on a per request basis
class RequestStore
	
	@actions
	@filters
	@client
	@service_path
	@gateway_path
	@actions_path
	@filters_path
	@adapters_path
	@logs_path
	@dbresult_adapters = []
	@use_backtraces
	@query_params = {}
	@net_debug
	@amf_encoding
	@recover_bad_xml_with_soup
  @use_sessions
  @vo_path
  @flex_messaging = false
  @recordset_format
  @gzip = false
  @rails = false
  @rails_authentication
  @available_services = {}
  @auth_header = nil
  @reload_services = false
  @config_path
  @app_instance
  @rails_request
  @rails_response
  @render_amf_results = false

	class << self
	  attr_accessor :actions
	  attr_accessor :filters
	  attr_accessor :client
	  attr_accessor :service_path
	  attr_accessor :gateway_path
	  attr_accessor :actions_path
	  attr_accessor :filters_path
	  attr_accessor :adapters_path
	  attr_accessor :logs_path
	  attr_accessor :dbresult_adapters
	  attr_accessor :use_backtraces
	  attr_accessor :query_params
	  attr_accessor :net_debug
	  attr_accessor :amf_encoding
	  attr_accessor :recover_bad_xml_with_soup
	  attr_accessor :use_sessions
	  attr_accessor :vo_path
	  attr_accessor :flex_messaging
	  attr_accessor :recordset_format
	  attr_accessor :gzip
	  attr_accessor :rails
	  attr_accessor :rails_authentication
	  attr_accessor :available_services
	  attr_accessor :auth_header
	  attr_accessor :config_path
	  attr_accessor :app_instance
	  attr_accessor :reload_services
	  attr_accessor :rails_request
	  attr_accessor :rails_response
	  attr_accessor :render_amf_results
	end

end
end
end