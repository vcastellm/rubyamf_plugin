require 'ostruct'
class ActiveRecordAdapter
  
  def use_adapter?(results)
    true
  end
  
  def run(results)
    debugger
    #method_hash = {:has_many => self.has_many, :belongs_to => self.belongs_to, :through => self.through, :has_and_belongs_to_many => self.has_and_belongs_to_many}
    result_object = self.walk(results)
    map = VoUtil.get_vo_definition_from_active_record(results.class.to_s)
    if map != nil
      results_object._explicitType = map[:outgoing]
    end
    debugger

    return result_object
    
  end

  #utility method for writing attributes on an active record
  def write_attributes(ar,ob)
    if ar.is_a? Array 
      write_multi_attributes(ar,ob) 
    else
      write_single_attributes(ar,ob)
    end
  end

  #turn the outgoing object into a VO if neccessary
  #map = VoUtil.get_vo_definition_from_active_record(ar.class.to_s)
  #if map != nil
  #  ob._explicitType = map[:outgoing]
  #end
  #ob


  def write_single_attributes(ar,ob)
    #debugger
    columns = ar.get_column_names
    columns.each do |column|
      val = ob.send(:"#{column}")
      eval("ob.#{column}=val")
    end
    ob
  end

  def write_multi_attributes(ar,ob)
    oba = []
    ar.each_with_index do |ar_x, i|
      #debugger
      columns = ar_x.get_column_names
      columns.each do |column|
        val = ob.send(:"#{column}")
        eval("ob.#{column}=val")
      end
      oba << ob
    end
    ob = oba
  end

  #utility method for checking deathly empties
  def is_empty?(ar)
    empty = false
    if ar.is_a?(Array)
      if ar.empty?
        empty = true
      end
    end
    if ar.nil? then empty = true end
    return empty
  end

  #absolute single meaning, one active record, no associations
  def absolute_single?(associations)
  #debugger
    if is_empty?(associations)
      return true
    end
    false
  end

  #utility method to find associations that were actually included in the query (":include")
  def active_associations(ar,associations)
  debugger
    aa= Array.new
    associations.class.reflections.keys.each do |key|
      if associations.class.reflections[key].instance_variables.include? "@klass" 
        aa << associations.class.reflections[key] 
      end
    end
    #debugger
    if aa.empty? then aa << associations end
    aa
  end

  #recursive result traversing.
  def walk(ar)
    #the final payload
    payload = OpenStruct.new
    #debugger
    if ar.class.to_s == "Array"
      #debugger
      
      active_associations(ar, ar[0]).each do |association|
        #if(absolute_single?(association))
        if association.is_a? ActiveRecord::Base
        payload =  write_attributes(ar,payload);
        else
        payload =  write_multiple(ar, association)
        end
      end
    else
      if ar.is_a?(ActiveRecord::Base)
        #debugger
        active_associations(ar, ar).each do |association|        
          if absolute_single?(association)
            payload = write_attributes(ar,payload)
          else
            payload = write_single(ar,association)
          end
        end
      end
    end
    payload
  end
  
  def write_single(ar, association)
    debugger
    payload = OpenStruct.new
    write_attributes(ar, payload)
      #association is an ActiveRecord::Reflection::Association class
      inflected_modelname = association.instance_values["name"]
      association_value = ar.send(inflected_modelname)
      debugger
      if !is_empty?(association_value)
      #if has no active associates .. 
        next_payload = self.walk(association_value)
        eval("payload.#{inflected_modelname.to_s}=next_payload")
      end
  payload
  end
  
  def write_multiple(ar, association)
    payload = []
    
    #store inflections in lookup for faster seeking
    inflections = []
    #associations.each do |association|
    #  inflections[association.class_name] = inflect(association.class_name)
    #end
    
    ar.each_with_index do |record,i|
      #write attributes on this object
      attributes_holder = OpenStruct.new
      payload[i] = write_attributes(ar[i],attributes_holder)
      #associations.each do |association|
      #association is an ActiveRecord::Reflection::Association class
      # debugger
      inflected_modelname = association.instance_values["name"]
         

      association_value = ar[i].send(inflected_modelname)
      #debugger

      if !is_empty?(association_value)
        next_payload = self.walk(association_value) 
        eval("payload[i].#{inflected_modelname.to_s}=next_payload")
      end
    end
  payload
  end
  
  #if an AR has a :belongs_to association, this method handles it.
  def belongs_to(ar)
  end
  
  #if an AR has a :has_many association, this method handles it.
  def has_many(ar)
  end
  
  #if an AR has a :though association, this method handles it.
  def through(ar)
  end
  
  #if an AR has a :has_and_belongs_to_many association, this method handles it.
  def has_and_belongs_to_many(ar)
  end
end
