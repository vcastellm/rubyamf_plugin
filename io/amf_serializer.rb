require 'app/amf'
require 'app/configuration'
require 'bigdecimal'
require 'date'
require 'io/read_write'
require 'ostruct'
require 'rexml/document'
require 'util/vo_util'
include RUBYAMF::AMF
include RUBYAMF::Configuration

module RUBYAMF
module IO

class AMFSerializer
	
	include RUBYAMF::IO::BinaryWriter
	attr_accessor :stream
	
	#write for RubyAMF
	def rubyamf_write(amfobj)
	  @amfobj = amfobj
		@stream = @amfobj.output_stream #grab the output stream for the amfobj
		
		#Which major types are considered adaptable. Array and Hash are as they are used for most DB results.
		#These are used to speed up the serialization process, otherwise ever single object written is run 
		#through Adapters.get_adapter_for_result which slows everything way down. yikes
		@adaptable_lookup = {'Array' => true,'Hash' => true,'String' => false,'Integer' => false,'Fixnum' => false,'Bignum' => false,
		'Float' => false,'Numeric' => false,'NilClass' => false,'ASRecordset' => false,'AS3DataProvider' => false,'TrueClass' => false,
		'FalseClass' => false,'Date' => false,'Time' => false,'DateTime' => false}
	  serialize
	end

	#write a ruby obj as raw AMF - for Unit testing
	def write_raw(obj,encoding = 3)
	  @stream = "" #new output stream
	  RequestStore.amf_encoding = (encoding == 3) ? 'amf3' : 'amf0'
	  reset_referencables
	  write(obj)
	  @stream
	end
	
	def reset_referencables
		@amf0_stored_objects = []
		@stored_strings = []
		@stored_objects = []
		@stored_defs = []
	end
	
	def serialize
		#write the amf version
		write_int16_network(0)
		
		@header_count = @amfobj.num_outheaders
		write_int16_network(@header_count)
		
		0.upto(@header_count - 1) do |i|
			#get the header obj at index
			@header = @amfobj.get_outheader_at(i)
			
			#write the header name
			write_utf(@header.name)
			
			#write the version
			write_byte(@header.required)
			write_word32_network(-1) #the usual four bytes of FF
			
			#write the header data
			write(@header.value)
		end
		
	  #num bodies
		@body_count = @amfobj.num_body
		write_int16_network(@body_count)
		
		0.upto(@body_count - 1) do |i|
			
			reset_referencables #reset any stored references in this scope
			
			#get the body obj at index
			@body = @amfobj.get_body_at(i)
						
			#write the response uri
			write_utf(@body.response_uri)
			
			#write null (usually target, no use for though)
			write_utf("null")
			write_word32_network(-1) #the usual four bytes of FF
			
			#write the results of the service call
			write(@body.results)
		end
	end
		
	#write Ruby data as AMF to output stream
	def write(value)	 
	  if Adapters.deep_adaptations
	    #if amf3, don't attempt any adaptations here. Otherwise this same call will be duplicated when we get to write_amf3
  	  if RequestStore.amf_encoding != 'amf3' && @adaptable_lookup[value.class.to_s] != false #true or nil will meet the condition, allowing an adaptation attempt
        if adapter = Adapters.get_adapter_for_result(value)
          value = adapter.run(value)
        end
      end
    end
    
	  if value.is_a?(ASRecordset) && (RequestStore.recordset_format == 'fl9' || RequestStore.recordset_format == 'fl.data.DataProvider')
	    write_data_provider(value)
	  
	  elsif RequestStore.amf_encoding == 'amf3'
		  write_byte(AMF3_TYPE)
		  write_amf3(value)
		  		
		elsif value.is_a?(ASRecordset)
		  write_recordset(value)
		
		elsif value.to_s == 'NaN' && value.object_id == NaN.object_id
      write_number(value.to_f)
		
    elsif value.to_s == 'Infinity' && value.object_id == Infinity.object_id
      write_byte(0x05)
      write_double(value.to_f)
    
    elsif value.to_s == "-Infinity" && value.object_id == NInfinity.object_id
      write_byte(0x05)
      write_double(value.to_f)
          
		elsif value.nil?
			write_null
    
    elsif value.is_a?(BigDecimal)
      write_number(value.to_f)
    
    elsif (value.is_a?(Float))
			write_number(value)
      
    elsif (value.is_a?(Bignum))
			write_number(value)
		
		elsif (value.is_a?(Integer))
			write_number(value)
		
		elsif (value.is_a?(Fixnum))
			write_number(value)
		
		elsif (value.is_a?(Numeric))
			write_number(value)

		elsif (value.is_a?(String))
			write_string(value)

		elsif (value.is_a?(TrueClass) || value.is_a?(FalseClass))
			write_booleanr(value)
		
    elsif(value.is_a?(OpenStruct))
      write_object(value)
    
		elsif (value.is_a?(Array))
			write_array(value)

		elsif (value.is_a?(Hash))
			write_hash(value)

		elsif (value.is_a?(Date))
			write_date(Time.local(value.year, value.month, value.day, 12, 00, 00, 00)) # Convert a Date into a time object
      
		elsif (value.is_a?(Time))
			write_date(value)

		elsif (value.instance_of?(REXML::Document))
			write_xml(value.write.to_s)
			
		elsif (value.class.to_s == 'BeautifulSoup')
      write_xml(value.to_s)

		else
			write_object(value)
		end
	end

  #AMF3
  def write_amf3(value)
    #adapt the result
    if Adapters.deep_adaptations
      if @adaptable_lookup[value.class.to_s] != false #true or nil will meet the condition, allowing an adaptation attempt
        if adapter = Adapters.get_adapter_for_result(value)
          value = adapter.run(value)
        end
      end
    end
    
    if value.to_s == 'NaN' && value.object_id == NaN.object_id
      write_byte(0x05)
      write_double(value.to_f)
    
    elsif value.to_s == 'Infinity' && value.object_id == Infinity.object_id
      write_byte(0x05)
      write_double(value.to_f)
    
    elsif value.to_s == "-Infinity" && value.object_id == NInfinity.object_id
      write_byte(0x05)
      write_double(value.to_f)
    
    elsif value.nil?
      write_byte(AMF3_NULL)
    
    elsif (value.is_a?(TrueClass) || value.is_a?(FalseClass))
      if(value == true)
        write_byte(AMF3_TRUE)
      else
        write_byte(AMF3_FALSE)
      end
          
    elsif value.is_a?(ASRecordset)
			write_amf3_recordset(value)
    
    elsif(value.is_a?(Integer))
      write_amf3_number(value)
    
    elsif(value.is_a?(Float))
      write_byte(0x05)
      write_double(value)
    
    elsif(value.is_a?(Bignum))
      write_byte(0x05)
      write_double(value)
    
    elsif value.is_a?(BigDecimal)
      value = value.to_s('F').to_f #this is turning a string into a Ruby Float, but because there are no further operations on it it is safe
      write_byte(0x05)
      write_double(value)
    
    elsif(value.is_a?(Fixnum))
      write_amf3_number(value)

    elsif(value.is_a?(String))
      write_byte(AMF3_STRING)
      write_amf3_string(value)
  
    elsif (value.is_a?(OpenStruct)) #easiest way to represent 'objects' here
      write_byte(AMF3_OBJECT)
			write_amf3_object(value)
    
    elsif(value.is_a?(Array))
      write_byte(AMF3_ARRAY)
      write_amf3_array(value)
    
    elsif(value.is_a?(Hash))
      write_amf3_mixed_array(value)
  
    elsif(value.is_a?(DateTime))
      write_byte(AMF3_DATE)
			write_time_as_amf3_date(value)
  
    elsif (value.is_a?(Date))
      write_byte(AMF3_DATE)
      write_amf3_date(value)
    
    elsif (value.is_a?(Time))
      write_byte(AMF3_DATE)
			write_time_as_amf3_date(value)
      
		elsif (value.is_a?(REXML::Document))
      write_byte(AMF3_XML)
      write_amf3_xml(value)
        
    elsif value.class.to_s == 'BeautifulSoup'
      write_byte(AMF3_XML)
      write_amf3_xml(value)

    elsif value.is_a?(Object)
      write_byte(AMF3_OBJECT)
      vo = VoUtil.get_vo_for_outgoing(value)
      write_amf3_object(vo)
		end
  end

  def write_amf3_integer(value)
		value = value & 0x1fffffff
		if(value < 0x80)
			write_byte(value)
		elsif(value < 0x4000)
			write_byte(value >> 7 & 0x7f | 0x80)
			write_byte(value & 0x7f)
		elsif(value < 0x200000)
			write_byte(value >> 14 & 0x7f | 0x80)
			write_byte(value >> 7 & 0x7f | 0x80)
			write_byte(value & 0x7f)
		else
			write_byte(value >> 22 & 0x7f | 0x80)
			write_byte(value >> 15 & 0x7f | 0x80)
			write_byte(value >> 8 & 0x7f | 0x80)
			write_byte(value & 0xff)
		end
  end
  
  def write_amf3_number(value)
    if(value >= AMF3_INTEGER_MIN && value <= AMF3_INTEGER_MAX) #check valid range for 29bits
			write_byte(0x04)
			write_amf3_integer(value)
		else
			#overflow condition otherwise
			write_byte(0x05)
			write_double(value)
		end
  end
  
	def write_amf3_string(value)
    if(value == "")
      write_byte(0x01)
    else
      i = @stored_strings.index(value)
      if (i != nil)
        reference = i << 1
        write_amf3_integer(reference)
      else
        @stored_strings << value
        reference = value.length
        reference = reference << 1
        reference = reference | 1
        write_amf3_integer(reference)
        writen(value)
      end
    end
	end
  
  def write_amf3_object(value)        
		i = @stored_objects.index(value)
		if i != nil
		  reference = i << 1
			write_amf3_integer(reference)
		else
		  members = value.get_members
	    
			#type this as a dynamic object
			write_byte(0x0B)
			
			classname = ""
			if(value._explicitType != nil)
			  classname = value._explicitType #override classname
			end
						
      @stored_objects << value #add object here for circular references
      
			write_amf3_string(classname)
      members.each_with_index do |v,i|
        if v == '_explicitType' || v == 'rmembers'
          next #skip _explicitType member, will cause ReferenceErrors
        end
        val = eval("value.#{v}")
        write_amf3_string(v)
        if(val == nil)
          write_byte(AMF3_NULL)
        else
          write_amf3(val)
        end
      end
            
			#close open object
			write_amf3_string("")
		end
  end
  
  def write_amf3_array(value)
    i = @stored_objects.index(value)
    if i != nil
      reference = i << 1
      write_amf3_integer(reference)
    else
      @stored_objects << value
      reference = value.length * 2 + 1
      write_amf3_integer(reference)
      write_amf3_string("")#write empty for string keyed elements here, as it's never allowed from ruby
      value.each_with_index do |v,k|
        write_amf3(v)
      end
    end
  end
  
  def write_amf3_mixed_array(value) #ruby hash to AMF3 dynamic object
    i = @stored_objects.index(value)
    if i != nil
      reference = i << 1
      #type as dynamic object
      write_byte(0x0A)
      write_amf3_integer(reference)
    else
      @stored_objects << value
      #Type this as a dynamic object
  		write_byte(0x0A)
  		write_byte(0x0B)
  		write_amf3_string("") #Anonymous object
      value.each do |k,v|
        write_amf3_string(k.to_s)
        write_amf3(v)
      end
  		write_amf3_string("")
  	end
  end
  
  def write_amf3_date(value)
    i = @stored_objects.index(value)
    if i != nil
      reference = i << 1
      write_amf3_integer(reference)
    else
      @stored_objects << value
      write_amf3_integer(1)
      t = Time.local(value.year, value.month, value.day, 12, 00, 00)
      write_double(t.to_f * 1000)
    end
  end
  
  def write_time_as_amf3_date(value)
    i = @stored_objects.index(value)
    if i != nil
      reference = i << 1
      write_amf3_integer(reference)
    else
      @stored_objects << value
      write_amf3_integer(1)
      t = Time.local(*(value.strftime("%Y,%m,%d,%H,%M,%S").split(','))) #splat the array into arguments for the Time.local method
      write_double(t.to_f * 1000)
    end
  end
  
  def write_amf3_xml(value)
    xml = value.to_s
    a = xml.strip
    if(a != nil)
      b = a.gsub!(/\>(\n|\r|\r\n| |\t)*\</,'><') #clean whitespace
    else
      b = xml.gsub!(/\>(\n|\r|\r\n| |\t)*\</,'><') #clean whitespace
    end
    write_amf3_string(b)
  end
  
  def write_amf3_recordset(value)
		numObjects = 0
    
		if RequestStore.flex_messaging
		  mode = 'ArrayCollection'
			write_byte(AMF3_OBJECT)
		  write_byte(AMF3_XML)
			write_amf3_string("flex.messaging.io.ArrayCollection")
			numObjects = numObjects + 1
		end
				
		#array
		write_byte(AMF3_ARRAY)
    numObjects = numObjects + 1
				
		numRows = value.row_count
		toPack = 2 * numRows + 1
		
		#num rows
		write_amf3_integer(toPack)
		
		#No string keys in this array
	  write_byte(AMF3_NULL)
				
		numCols = value.column_names.length
		if(numRows > 0)
			colNames = []
			rows = value.initial_data
			rows.each_with_index do |line,k|
        
				#write a non object code
				write_byte(AMF3_OBJECT)
				write_byte(AMF3_XML_STRING)
				write_byte(AMF3_NULL)
				numObjects = numObjects + 1
        
				0.upto(numCols - 1) do |i|
					#column name
					write_amf3_string(value.column_names[i])
					v = line[i]
					if(v.is_a?(Integer)) #only allow certain types to be written, as a 'recordset' only has basic types
					  write_amf3_number(v)
					
					elsif(v.is_a?(Float) || v.is_a?(Bignum) || v.is_a?(Fixnum))
					  write_byte(AMF3_NUMBER)
					  write_double(v)
					
					elsif(v.is_a?(String))
					  write_byte(AMF3_STRING)
						write_amf3_string(v)
					
					elsif(v.nil?)
					  write_byte(AMF3_NULL)
					
					elsif(v.is_a?(Date))
					  write_byte(AMF3_STRING)
					  write_amf3_string(v.to_s)
					
					elsif(v.is_a?(Time))
					  write_byte(AMF3_STRING)
						write_amf3_string(v)
          
          elsif(v.is_a?(DateTime))
            write_byte(AMF3_STRING)
            write_amf3_string(v.to_s)
          
          elsif (v.is_a?(TrueClass) || v.is_a?(FalseClass))
            if(v == true)
              write_byte(AMF3_TRUE)
            else
              write_byte(AMF3_FALSE)
            end
					end
				end

        #end of object
				write_amf3_string("")
			end
		end
		
		0.upto(numObjects - 1) do |i|
		  @stored_objects << ""
		end
  end

  
  #####################################################
  #AMF0
  #####################################################
  #this writes an Actionscript 3 DataProvider, technically this is Flash9/AS3 
	#but if you use remoting with Flash 9 and NetStreams, it will use AMF0 format
  def write_data_provider(asrs)
		write_byte(10) #write Array
		write_word32_network(asrs.row_count) #array length
		columns = asrs.column_names
    0.upto(asrs.row_count - 1) do |i|
      h = {}
      0.upto(columns.length - 1) do |c|
        key = columns[c]
        val = asrs.initial_data[i][c]
        h[key] = val
      end
      write_hash(h)
    end
  end

	#write a recordset
	def write_recordset(asrs)
		write_byte(16) #write custom object flag
		write_utf('RecordSet') #write the specific class type
		write_utf('serverInfo')
		write_byte(3) #object, write object code

		#write total count of records
		write_utf('totalCount')
		if( asrs.is_pageable == true)
			write_number(asrs.total_count)
		else
			write_number(asrs.row_count)
		end

		#write column names
		write_utf('columnNames')
		write_array(asrs.column_names.clone)

		#write initial data
		write_utf('initialData')
		write_array(asrs.initial_data)

		#write cursor position
		write_utf('cursor')
		write_number(1)

		#write service name, to use when paging
		write_utf('serviceName')
		write_string(asrs.service_name) #hard code this method name, watch for when getPage is called, then invoking by the id passed

		#write version
		write_utf('version')
		write_number(1)

		#write id
		write_utf('id')
		write_string(asrs.id)

		#end inner server info object
		write_int16_network(0)
		write_byte(9)

		#end outer recordset object
		write_int16_network(0)
		write_byte(9)
	end
  
	#write a recorset PAGE
	def write_recordset_page(asrpage)	
		write_byte(16) #write custom object flag
		write_utf('RecordSetPage') #write the specific class type

		#write cursor position
		write_utf('Cursor')
		write_number(asrpage.cursor)

		#write the page data
		write_utf('Page')

		#writed the data
		write_array(asrpage.value) #write the data

		#end outer object
		write_int16_network(0)
		write_byte(9)
	end

	# Write a Flash Null
	def write_null
		write_byte(5)
	end

	# Write Flash Number object
	def write_number(numeric)
		write_byte(0)
		write_double(numeric)
	end

	# Write a Flash String object
	def write_string(string)
		write_byte(2)
		write_utf(string.to_s)
	end

	# Write a Flash Boolean object
	def write_booleanr(bool)
		write_byte(1)
		write_boolean(bool)
	end

	# Write a Flash Date object
	def write_date(time)
		write_byte(11)
		write_double(time.to_f * 1000)
		offset = Time.zone_offset(Time.now.zone)
		write_int16_network(offset / 60 * -1)
	end

	#writes a Flash Array
	def write_array(array)
		write_byte(10)
		write_word32_network(array.length)
		array.each do |el| 
			write(el)
		end
	end

	# writes a hash as an object
	def write_hash(hash)
		write_byte(3)
		hash.each do |key, value|
			write_utf(key.to_s)
			write(value)
		end

		# write the end object flag 0x00, 0x00, 0x09
		write_int16_network(0)
		write_byte(9)
	end

	#write an object
	def write_object(object)
		begin
  		if object._explicitType != nil
  			write_byte(16)
  			write_utf(object._explicitType)
  		else
  			write_byte(3)
  		end
    rescue Exception => e #when _explicitType or customKlazz isn't available
      write_byte(3)
    end
    
	  begin
	    members = object.get_members
			#if object.rmembers != nil
			#  members = object.rmembers
			#elsif(object.is_a?(OpenStruct))
      #  members = object.marshal_dump.keys.map{|k| k.to_s} #returns an array of all the keys in the OpenStruct
			#else
			#  members = object.instance_variables.map{|mem| mem[1,mem.length]}
			#end
	  rescue Exception => e
	    #if exception from testing against value.rmembers is thrown, catch here and make sure to set members
	    if(object.is_a?(OpenStruct))
        members = object.marshal_dump.keys.map{|k| k.to_s} #returns an array of all the keys in the OpenStruct
			else
			  members = object.instance_variables.map{|mem| mem[1,mem.length]}
			end
	  end
    
		#Loop through the accessor method names, invoking each accessor on the object,writng each value
		members.each do |key|
		  begin
  		  if key == nil || key == '' || key == 'method' || key == "_explicitType" || key == "rmembers"
  		    next
  		  end
  			write_utf(key)
  			write(eval("object.#{key}"))
  		rescue Exception => e
  		end
		end
    
		#write the end object flag 0x00, 0x00, 0x09
		write_int16_network(0)
		write_byte(9)
	end
  
	#writes a string of xml
	def write_xml(xml_string)
		write_byte(AMF_XML)
		write_long_utf(xml_string.to_s)
	end

end
end
end