require 'app/amf'
include RUBYAMF::AMF

#A lafcadio ORM adapter
class LafcadioAdapter
  
  def use_adapter?(results)
    if(results.class.superclass.to_s == 'Lafcadio::DomainObject' || results[0].class.superclass.to_s == 'Lafcadio::DomainObject')
      return true
    end
    false
  end
  
  def run(result)
    if(results.class.superclass.to_s == 'Lafcadio::DomainObject')
      results = run_single(result)
      return results
    elsif(results[0].class.superclass.to_s == 'Lafcadio::DomainObject')
      results = run_multiple(result)
      return results
    end
  end
  
  def run_single(results)
    column_names = result.class.class_fields.map {|field| field.name}
    row_count = '1'
    intial_data = results.map do |item|
      column_names.map { |col| item.send(col) }
    end
    
    asrecordset = ASRecordset.new(row_count,column_names,initial_data)
		results = asrecordset
	  results
  end
  
  def run_multiple(results)
    column_names = result.class.class_fields.map {|field| field.name}
    row_count = results.size
    intial_data = results.map do |item|
      column_names.map { |col| item.send(col) }
    end
    
    asrecordset = ASRecordset.new(row_count,column_names,initial_data)
		results = asrecordset
	  results
  end
end