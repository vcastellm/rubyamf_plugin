require 'app/amf'
include RUBYAMF::AMF

#Adapt a Mysql::Result class into an array of objects
class MysqlAdapter
	
	def use_adapter?(result)
    if result.class.to_s == 'Mysql::Result'
      return true
    end
    false
	end
	
	def run(result)
	  payload = Array.new
	  result.data_seek(0)
		while row = result.fetch_hash
			payload << row
		end
		#if only one row, make it an object
		if payload.length == 1
		  payload = payload[0]
		end
		payload
	end
end