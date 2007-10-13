require 'ostruct'

class ActiveRecordAdapter
  
  #should we use this adapter for the result type
  def use_adapter?(results)
    if(use_multiple?(results) || use_single?(results))
      return true
    end
    false
  end
  
  #run the results through this adapter
  def run(results)
    res1 = results

    if(use_multiple?(results))
      results = run_multiple(results)
    else
      results = run_single(results)
    end
    return results
  end

  def get_reflected_attributes(res1, o)
    if (associations = res1.get_associates) == nil then associations = Array.new end
    if res1.class.reflections.keys.size > 0
      res1.class.reflections.keys.each do |x|
        obj="#{x}"
        unless associations.include?('@'+obj)
          through_data = Array.new
          is_through = res1.send(x)
          if !is_empty?(is_through)
            use_single?(is_through) ? through_data = run_single(is_through) : through_data = run_multiple(is_through)
          end
          eval("o.#{obj}=through_data")
        end
      end
    end
  end

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


  #is the result an array of active records
  def use_multiple?(results)
    if(results.class.to_s == 'Array' && results[0].class.superclass.to_s == 'ActiveRecord::Base')
      return true
    end
    false
  end

  #is this result a single active record?
  def use_single?(results)
    if(results.class.superclass.to_s == 'ActiveRecord::Base')
      return true
    end
    false
  end 

  #run the data extaction process on an array of AR results
  def run_multiple(um)
    initial_data = []
    column_names = um[0].get_column_names
    num_rows = um.length
    
    c = 0
    0.upto(num_rows - 1) do
      o = OpenStruct.new
      class << o
        attr_accessor :id
      end
      
      #turn the outgoing object into a VO if neccessary
      map = VoUtil.get_vo_definition_from_active_record(um[0].class.to_s)
      if map != nil
        o._explicitType = map[:outgoing]
      end
      
      #first write the primary "attributes" on this AR object
      #no need for an index 
      column_names.each do |v|
        val = um[c].send(:"#{v}")
        vo_property = ValueObjects.translate_case ? v.camlize(:lower) : v
        eval("o.#{vo_property}=val")
      end
      
      associations = um[0].get_associates
      if(!associations.empty?)
        #now write the associated models with this AR
        associations.each do |associate|
          na = associate[1, associate.length]
          ar = um[c].send(:"#{na}")         
          if !is_empty?(ar)
            if(use_single?(ar))
              initial_data_2 = run_single(ar)   #recurse into single AR method for same data structure
            else
              initial_data_2 = run_multiple(ar) #recurse into multiple AR method for same data structure
            end
            eval("o.#{na}=initial_data_2")
            get_reflected_attributes(um[c], o)
          end
        end
      end
      c += 1
      initial_data << o
    end
    initial_data
  end
  
  #run the data extraction process on a single AR result
  def run_single(us)
    initial_data = []
    column_names = us.get_column_names
    num_rows = 1
    
    c = 0
    0.upto(num_rows - 1) do
      o = OpenStruct.new
      class << o
        attr_accessor :id
      end

      #turn the outgoing object into a VO if neccessary
      map = VoUtil.get_vo_definition_from_active_record(us.class.to_s)
      if map != nil
        o._explicitType = map[:outgoing]
      end
      
      #first write the primary "attributes" on this AR object
      column_names.each do |v|
        val = us.send(:"#{v}")
        vo_property = ValueObjects.translate_case ? v.camlize(:lower) : v
        eval("o.#{vo_property}=val")
      end
      
      associations = us.get_associates
      if(!associations.empty?)
        #now write the associated models with this AR
        associations.each do |associate|
          na = associate[1, associate.length]
          ar = us.send(:"#{na}")          
          if !is_empty?(ar)
            if(use_single?(ar))
              initial_data_2 = run_single(ar)   #recurse into single AR method for same data structure
            else
              initial_data_2 = run_multiple(ar) #recurse into multiple AR method for same data structure
            end             
            eval("o.#{na}=initial_data_2")
            get_reflected_attributes(us, o)
          end
        end
      end
      
      #commented out following lines in 1.3.4 - this makes single active records "as_single" permanent no matter what
      #if us.single?
      initial_data = o
      #else
      #  initial_data << o
      #end
      c += 1
    end
    initial_data
  end
end


=begin
TESTING = true
require 'rubygems'
require 'active_record'
require '../../services/org/universalremoting/browser/support/ar_models/user'
require '../../services/org/universalremoting/browser/support/ar_models/address'
require '../util/active_record'

ar = ActiveRecordAdapter.new

ActiveRecord::Base.establish_connection(:adapter => 'mysql', :host => 'localhost', :password => '', :username => 'root', :database => 'ar_rubyamf_testings')

### multiple results, including some other associations
mult = User.find(:all, :include => :addresses)

### single result
sing = User.find(402, :include => :addresses)

final = ar.run_multiple(mult)
puts "MULTIPLE -> RESULTS"
puts '--------------'
puts final.inspect
puts '--------------'
puts final[0].inspect

puts "\n\n"

finals = ar.run_single(sing)
puts "SINGLE -> RESULT"
puts '--------------'
puts finals.inspect
puts '--------------'
puts finals[0].inspect
=end
