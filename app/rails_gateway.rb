# require 'app/gateway'
require 'app/request_store'
require 'app/amf'
require 'app/actions'
require 'app/filters'
require 'app/configuration'
require 'zlib'
module RubyAMF
  module App
    #Rails Gateway, extends regular gateway and changes the actions
    class RailsGateway

      include RubyAMF::Actions
      include RubyAMF::AMF
      include RubyAMF::Configuration
      include RubyAMF::Filter
      include RubyAMF::App # for RequestStore
      include RubyAMF::Exceptions
  
      def initialize
        RequestStore.filters = Array[AMFDeserializerFilter.new, AuthenticationFilter.new, BatchFilter.new, AMFSerializeFilter.new] #create the filter
        RequestStore.actions = Array[PrepareAction.new, RailsInvokeAction.new] #override the actions
      end

      #all get and post requests circulate throught his method
      def service(raw)
        amfobj = AMFObject.new(raw)
        FilterChain.new.run(amfobj)
        RequestStore.gzip ? Zlib::Deflate.deflate(amfobj.output_stream) : amfobj.output_stream
      end
    end
  end
end