require 'io/amf_deserializer'
require 'io/amf_serializer'
require 'exception/exception_handler'
module RubyAMF
  module Filter
    
    class FilterChain
      include RubyAMF::App
      def run(amfobj)
        RequestStore.filters.each do |filter| #grab the filters to run through
          filter.run(amfobj)
          # puts "#{filter}: " +Benchmark.realtime{}.to_s
        end
      end
    end
    
    class AMFDeserializerFilter
      include RubyAMF::IO  
      def run(amfobj)
        AMFDeserializer.new.rubyamf_read(amfobj)
      end
    end

    class AuthenticationFilter
      include RubyAMF::App
      def run(amfobj)
        RequestStore.auth_header = nil # Aryk: why do we need to rescue this? 
        if (auth_header = amfobj.get_header_by_key('Credentials'))
          RequestStore.auth_header = auth_header #store the auth header for later
          RequestStore.rails_authentication = {:username => auth_header.value['userid'], :password => auth_header.value['password']}
        end
      end
    end

    class BatchFilter
      include RubyAMF::App
      include RubyAMF::Exceptions
      def run(amfobj)
        body_count = amfobj.num_body
        0.upto(body_count - 1) do |i| #loop through all bodies, do each action on the body
          body = amfobj.get_body_at(i)
          RequestStore.actions.each do |action|
            begin #this is where any exception throughout the RubyAMF Process gets transformed into a relevant AMF0/AMF3 faultObject
              action.run(body)
              # puts "#{action} took: " + Benchmark.realtime{action.run(body)}.to_s + " secs"
            rescue RUBYAMFException => ramfe
              puts ramfe.message
              puts ramfe.backtrace
              ramfe.ebacktrace = ramfe.backtrace.to_s
              ExceptionHandler::HandleException(ramfe,body)
            rescue Exception => e
              puts e.message
              puts e.backtrace
              ramfe = RUBYAMFException.new(e.class.to_s, e.message.to_s) #translate the exception into a rubyamf exception
              ramfe.ebacktrace = e.backtrace.to_s
              ExceptionHandler::HandleException(ramfe, body)
            end
          end
        end
      end
    end

    class AMFSerializeFilter
      include RubyAMF::IO
      def run(amfobj) 
        AMFSerializer.new(amfobj).run 
      end
    end
  end
end