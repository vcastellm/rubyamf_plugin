require 'app/amf'
include RUBYAMF::AMF

class OracleOCI8Adapter
  
  def use_adapter?(result)
    #not implemented
    false
  end
	
	# run the action on an AMFBody#result instance var
	def run(result)		
		column_names = result.get_col_names #store the column names
		row_count = result.row_count
		initial_data = Array.new #payload holder
    while row = result.fetch
      initial_data << row # add a row to the payload
    end
		asrecordset = ASRecordset.new(row_count,column_names,initial_data)
		result = asrecordset		
	end
end
