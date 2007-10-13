require 'app/amf'
require 'exception/exception_handler'
require 'io/amf_serializer'
require 'io/amf_deserializer'
include RUBYAMF::App
include RUBYAMF::Exceptions
include RUBYAMF::IO

module RUBYAMF
module Filter

class FilterChain
	def run(amfobj)
	  filters = RequestStore.filters #grab the filters to run through
		filters.each do |filter|
			filter.run(amfobj)
		end
	end
end

class AMFDeserializerFilter
	def run(amfobj)
		deserialize = AMFDeserializer.new
		deserialize.rubyamf_read(amfobj)
	end
end

class RecordsetFormatFilter
  def run(amfobj)
    begin
      format = amfobj.get_header_by_key('recordset_format').value #see if there is a recordset format set for Flash 8 VS Flash 9
      if format != false && (format == 'mx.remoting.RecordSet' || format == 'fl.data.DataProvider' || format == 'fl8' || format == 'fl9')
        RequestStore.recordset_format = format
      end
    rescue Exception => e #do nothing, defaults Flash 8 mx.remoting.RecordSet
    end
  end
end

class AuthenticationFilter
	def run(amfobj)
	  begin
	    RequestStore.auth_header = nil
	  rescue Exception => e
	  end
		auth_header = amfobj.get_header_by_key('Credentials')
		if auth_header
		  RequestStore.auth_header = auth_header #store the auth header for later
		  if RequestStore.rails
		    RequestStore.rails_authentication = {:username => auth_header.value.userid, :password => auth_header.value.password}
		  end
		  return
		else
			return
		end
	end
end

class BatchFilter
	def run(amfobj)
		body_count = amfobj.num_body
		0.upto(body_count - 1) do |i| #loop through all bodies, do each action on the body
			body = amfobj.get_body_at(i)
			RequestStore.actions.each do |action|
				begin #this is where any exception throughout the RubyAMF Process gets transformed into a relevant AMF0/AMF3 faultObject
					action.run(body)
				rescue RUBYAMFException => ramfe
				  ramfe.ebacktrace = ramfe.backtrace.to_s
					ExceptionHandler::HandleException(ramfe,body)
				rescue Exception => e
					ramfe = RUBYAMFException.new(e.class.to_s, e.message.to_s) #translate the exception into a rubyamf exception
					ramfe.ebacktrace = e.backtrace.to_s
					ExceptionHandler::HandleException(ramfe, body)
				end
  		end
		end
	end
end

class AMFSerializeFilter
	def run(amfobj)
		serializer = AMFSerializer.new
		serializer.rubyamf_write(amfobj)
	end
end

end
end