require 'app/amf'
include RUBYAMF::AMF

# Java Hypersonic Database Adapter
# You'll need the "Yet Another Java Bridge" ruby/java bridge
# http://rubyforge.org/projects/hypersonic/
class HypersonicAdapter
	
	def use_adapter?(result)
	  #not implemented
	  false
	end
	
	# run the action on an AMFBody#result instance var
	def run(result)
		column_names = result.column_names #store the column names
		initial_data = Array.new #payload holder
		row_count = result.length
		asrecordset = ASRecordset.new(row_count,column_names,initial_data)
	end
end
