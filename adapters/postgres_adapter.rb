require 'app/amf'
include RUBYAMF::AMF

#Adapt a PGresult class into an ASRecordSet
class PostgresAdapter
	
	#use the postgres adapter?
	def use_adapter?(results)
    if results.class.to_s == 'PGresult'
	    return true
	  end
    false
	end
	
	#run the action on an AMFBody#result instance var
	def run(result)		
		column_names = result.fields #store the column names
		row_count = result.num_tuples #get the number of rows in the result
		initial_data = Array.new #payload holder
    result.each do |item|
      intial_data << item.to_ary
    end		
		asrecordset = ASRecordset.new(row_count,column_names,initial_data)
		result = asrecordset
		results
	end
end
