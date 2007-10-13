require 'app/amf'
include RUBYAMF::AMF

#Nitro Object Graph adapter
class ObjectGraphAdapter
  
  #need to use this adapter for objectgraph?
  def use_adapter?(results)
    if(results.class.superclass.to_s == 'Og::Model' || results[0].class.superclass.to_s == 'Og::Model')
      return true
    end
    false
  end
  
  #When multiple Og::Model
  def run_multiple(results)
    column_names = resuls.class.serialize_attributes
    row_count = results.size
    initial_data = []
    results.each do |item|
      data << item
    end
    asrecordset = ASRecordset.new(row_count,column_names,initial_data)
		result = asrecordset
		result
  end
  
  #when one Og::Model
  def run_singe(results)
    column_names = results.class.serialize_attributes
    row_count = 1
    initial_data = results[0];
    asrecordset = ASRecordset.new(row_count,column_names,initial_data)
		result = asrecordset
		result
  end
  
end