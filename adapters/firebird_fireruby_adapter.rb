require 'app/amf'
include RUBYAMF::AMF

#Firebird - FireRuby
class FirebirdFirerubyAdapter
	
	def use_adapter?(result)
	  #not implemented
	  false
	end
	
	# run the action on an AMFBody#result instance var
	def run(result)		
		column_names = result.column_names #store the column names
		initial_data = Array.new #payload holder
		row_count = result.row_count
    result.each do |row|
			initial_data << row # add a row to the payload
		end
		asrecordset = ASRecordset.new(row_count,column_names,initial_data)
		result = asrecordset		
	end
end
