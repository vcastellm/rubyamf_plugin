require 'app/amf'
include RUBYAMF::AMF

# Adapt an RubyDBI result into an ASRecordSet
class RubyDBIAdapter
	
	def use_adapter?(result)
	  #not implemented
	  false
	end
	
	# run the action on an AMFBody#result instance var
	def run(result)		
		column_names = result.column_names #store the column names
		row_count = result.fetch_all.size #get the number of rows in the result
		initial_data = Array.new #payload holder
    result.fetch do |row|
      initial_data << row # add a row to the payload
    end
		asrecordset = ASRecordset.new(row_count,column_names,initial_data)
		result = asrecordset		
	end
end
