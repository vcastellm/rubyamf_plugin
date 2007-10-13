require 'app/amf'
include RUBYAMF::AMF

#Adapt a Sqlite result into an ASRecordSet
class SqliteAdapter
	
	def use_adapter?(result)
	  #not implemented
	  false
	end
	
	#run the action on an AMFBody#result instance var
	def run(result)
		column_names = result.columns #store the column names
		initial_data = Array.new #payload holder
		row_count = 0
    result.each do |row|
      row_count += 1
			initial_data << row # add a row to the payload
		end
		asrecordset = ASRecordset.new(row_count,column_names,initial_data)
		result = asrecordset
	end
end
