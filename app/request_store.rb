module RubyAMF
  module App

    #store information on a per request basis
    class RequestStore
      @render_amf_results = false
      @flex_messaging = false
      @auth_header = nil
      @rails_authentication
      @reload_services = false
      @gzip = false
      @service_path = File.expand_path(Rails::VERSION::MAJOR < 3 ? RAILS_ROOT : ::Rails.root.to_s) + '/app/controllers' #fosrias: RAILS_ROOT deprectated in Rails 3
      
      class << self
        attr_accessor :amf_encoding
        attr_accessor :service_path
        attr_accessor :filters
        attr_accessor :actions
        attr_accessor :rails_request
        attr_accessor :rails_response
        attr_accessor :render_amf_results
        attr_accessor :flex_messaging
        attr_accessor :auth_header
        attr_accessor :rails_authentication
        attr_accessor :reload_services
        attr_accessor :gzip
      end
    end
  end
end