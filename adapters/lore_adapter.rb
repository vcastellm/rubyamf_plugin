require 'app/amf'
include RUBYAMF::AMF

# Lore is yet another ORM
class LoreAdapter
	
	def use_adapter?(result)
    false
	end
	
	# run the action on an AMFBody#result instance var
	def run(result)
		column_names = result.get_field_names #store the column names
		initial_data = result.get_rows #payload holder
		row_count = initial_data.length
		asrecordset = ASRecordset.new(row_count,column_names,initial_data)
		result = asrecordset		
	end
end
