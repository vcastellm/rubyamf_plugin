require 'app/request_store'
require 'app/amf'
require 'date'
require 'exception/rubyamf_exception'
require 'io/read_write'
require 'util/vo_util'
require 'kconv'
require 'rexml/document'
include RUBYAMF::AMF
include RUBYAMF::App
include RUBYAMF::Exceptions

module RUBYAMF
module IO

class AMFDeserializer
	
	include RUBYAMF::IO::BinaryReader
	attr_accessor :stream
	attr_accessor :stream_position
	
	def initialize
		@raw = true
	  @rawkickoff = true
	  @stream_position = 0
    reset_referencables
	end
	
	#do an entire read operation on a complete amf request
	def rubyamf_read(amfobj)
		RequestStore.amf_encoding = 'amf0'
		@amfobj = amfobj
		@stream = @amfobj.input_stream
		@raw = false
	  @rawkickoff = false
	  preamble
		headers
		bodys
	end
  
  #read some raw amf data. (this does not include preamble, headers, bodys.. just raw amf types)
	def read_raw(stream, format=3)
	  @stream = stream
	  @stream_position = 0
	  @raw = true
	  @rawkickoff = true
	  reset_referencables
    obj = read(nil)
    obj
	end
	
	def reset_referencables
		@amf0_stored_objects = []
		@stored_strings = []
		@stored_objects = []
		@stored_defs = []
	end
  
	def preamble
		version = read_int8 #first byte, not anything important
		if version != 0 && version != 3
			raise RUBYAMFException.new(RUBYAMFException.VERSION_ERROR, "The amf version is incorrect")
		end
		
		#read the client. (0x00 - Flash Player, 0x01 - FlashComm)
		client = read_int8
		RequestStore.client = client
	end
	
	def headers
	  @in_headers = true #processing headers
	  
	  #Find total number of header elements
		header_count = read_word16_network
    
		0.upto(header_count - 1) do
			
			#find the key of the header
			name = read_utf
			
			#Find the must understand flag
			required = read_booleanr

			#Grab the length of the header element
			length = read_word32_network
			
			#Grab the type of the element
			type = read_byte
			
			#Turn the element into real data
			value = read(type)
			
			#create new header
			header = AMFHeader.new(name,required,value)
      
			#add header to the amfbody object
			@amfobj.add_header(header)
		end
	end
	
	def bodys
	  @in_headers = false #no more headers
	  
		#find the total number of body elements
		body_count = read_int16_network
	  
		#Loop over all the body elements
		0.upto(body_count - 1) do
			
			reset_referencables
			
			#The target method
			target = read_utf
			
			#The unique id that the client understands
			response = read_utf
			
			#Get the length of the body element
			length = read_word32_network

			#Grab the type of the element
			type = read_byte

			#Turn the argument elements into real data
			value = read(type)
			
			#new body
			body = AMFBody.new(target,response,value)
			
			#add the body to the amfobj 
			@amfobj.add_body(body)
		end	  
	end
  
  #Reads object data by type from @input_stream
	def read(type)	  
    #for amf unit tests or raw amf data
    if @raw == true && @rawkickoff == true #rawkickoff is a flag so that the initial type is never read again
      type = read_byte
      @rawkickoff = false
		end
		
		case type
		  when AMF3_TYPE
			  RequestStore.amf_encoding = 'amf3'
			  RequestStore.use_sessions = false #shut off sessions(for RubyAMF standalone app servers) as soon as amf3 is used
			  read_amf3
			when AMF_NUMBER
				read_number
			when AMF_BOOLEAN
				read_booleanr
			when AMF_STRING
				read_string
			when AMF_OBJECT
				read_object
			when AMF_MOVIE_CLIP
			  raise RUBYAMFException.new(RUBYAMFException.UNSUPPORTED_AMF0_TYPE, 'You cannot send a movie clip')
			when AMF_NULL
				nil
			when AMF_UNDEFINED
				nil
			when AMF_REFERENCE
				nil #TODO Implement this
			when AMF_MIXED_ARRAY
				length = read_int32_network #long, don't do anything with it
				read_mixed_array
			when AMF_EOO
				nil
			when AMF_ARRAY
				read_array
			when AMF_DATE
				read_date
			when AMF_LONG_STRING
				utflen = read_int32_network #don't touch the length
				read_utf
			when AMF_UNSUPPORTED
				raise RUBYAMFException.new(RUBYAMFException.UNSUPPORTED_AMF0_TYPE, 'Unsupported type')
			when AMF_RECORDSET
			  raise RUBYAMFException.new(RUBYAMFException.UNSUPPORTED_AMF0_TYPE, 'You cannot send a RecordSet to RubyAMF, although you can receive them from RubyAMF.')
			when AMF_XML
				read_xml
			when AMF_TYPED_OBJECT
			  read_custom_class
		end
	end
	
	#AMF3
  def read_amf3
    type = read_word8
    case type
      when AMF3_UNDEFINED
        nil
      when AMF3_NULL
        nil
      when AMF3_FALSE
        false
      when AMF3_TRUE
        true
      when AMF3_INTEGER
        read_amf3_integer
      when AMF3_NUMBER
        read_number #read standard AMF0 number, a double
      when AMF3_STRING 
      	read_amf3_string
  		when AMF3_XML
  		  read_amf3_xml_string
  		when AMF3_DATE
  		  read_amf3_date
  		when AMF3_ARRAY
  			read_amf3_array
  	  when AMF3_OBJECT
  	    read_amf3_object
  	  when AMF3_XML_STRING
  	    read_amf3_xml
  	  when AMF3_BYTE_ARRAY
  	    read_amf3_byte_array
    end
  end
  
  def read_amf3_integer
    n = 0
    b = read_word8
    result = 0
    
    while ((b & 0x80) != 0 && n < 3)
        result = result << 7
        result = result | (b.to_i & 0x7f)
        b = read_word8
        n = n + 1
    end
    
    if (n < 3)
      result = result << 7
      result = result | b
    else
    	#Use all 8 bits from the 4th byte
    	result = result << 8
    	result = result | b
    	
    	#Check if the integer should be negative
    	if ((result & 0x10000000) != 0)
    		result |= 0xe0000000
    	end
    end
    
    if result.to_s == '-Infinity'
	    return NInfinity
	  end
    return result
  end
  
  def read_amf3_string
    type = read_amf3_integer
    isReference = (type & 0x01) == 0
    if isReference
      reference = type >> 1
      if reference < @stored_strings.length
        if @stored_strings[reference] == nil
          raise( RUBYAMFException.new(RUBYAMFException.UNDEFINED_OBJECT_REFERENCE_ERROR, "Reference to non existant string at index #{reference}, please tell aaron@rubyamf.org"))
        end
        return @stored_strings[reference]
      else
        raise( RUBYAMFException.new(RUBYAMFException.UNDEFINED_STRING_REFERENCE_ERROR, "Reference to non existant string at index #{reference}, please tell aaron@rubyamf.org") )
      end
    else
      
      length = type >> 1
      
      #Note that we have to read the string into a byte buffer and then
      #convert to a UTF-8 string, because for standard readUTF() it
      #reads an unsigned short to get the string length.
      #A string isn't stored as a reference if it is the empty string
      #thanks Karl von Randow for this
      if length > 0
        str = String.new(readn(length)) #specifically cast as string, as we're reading verbatim from the stream
        str.toutf8 #convert to utf8
        @stored_strings << str
      end
      return str
    end
  end
  
  def read_amf3_xml
  	type = read_amf3_integer
  	isReference = (type & 0x01) == 0
  	if isReference
  	  reference = type >> 1
  		if @stored_objects[reference] == nil
  		  raise( RUBYAMFException.new(RUBYAMFException.UNDEFINED_OBJECT_REFERENCE_ERROR, "Reference to non existant xml string at index #{reference}, please tell aaron@rubyamf.org"))
  		end
  		xml = @stored_objects[reference]
  	else
      length = type >> 1
  		xml = readn(length)
  	end
  	@stored_objects << xml
  	return xml
  end
  
  def read_amf3_date
    type = read_amf3_integer
    isReference = (type & 0x01) == 0
    if isReference
      reference = type >> 1
      if reference < @stored_objects.length
        if @stored_objects[reference] == nil
          raise( RUBYAMFException.new(RUBYAMFException.UNDEFINED_OBJECT_REFERENCE_ERROR, "Reference to non existant date at index #{reference}, please tell aaron@rubyamf.org"))
        end
        return @stored_objects[reference]
      else
        raise( RUBYAMFException.new(RUBYAMFException.UNDEFINED_OBJECT_REFERENCE_ERROR, "Undefined date object reference when deserialing AMF3: #{reference}") )
      end
    else
      ms = read_double
      t = Time.at( ms.to_f / 1000.0 )
      nd = DateTime.new(t.year, t.month, t.day, t.hour, t.min, t.sec)
      @stored_objects << nd
      return nd
    end
  end
  
  def read_amf3_array
    type = read_amf3_integer
    isReference = (type & 0x01) == 0
    
    if isReference
      reference = type >> 1
      if reference < @stored_objects.length
        if @stored_objects[reference] == nil
          raise(RUBYAMFException.new(RUBYAMFException.UNDEFINED_OBJECT_REFERENCE_ERROR, "Reference to non existant array at index #{reference}, please tell aaron@rubyamf.org"))
        end
        return @stored_objects[reference]
      else
        raise Exception.new("Reference to non-existent array at index #{reference}, please tell aaron@rubyamf.org")
      end
    else
      length = type >> 1
      propertyName = read_amf3_string
      if propertyName != nil
      	array = {}
      	begin
      	  while(propertyName.length)
      		  value = read_amf3
      		  array[propertyName] = value
      		  propertyName = read_amf3_string
          end
        rescue Exception => e #end of object exception, because propertyName.length will be non existent
        end
        
      	0.upto(length - 1) do |i|
      	  array["" + i.to_s] = read_amf3
    	  end
        
        @stored_objects << array
        return array
      else
        array = []
        0.upto(length - 1) do
          array << read_amf3
        end
        @stored_objects << array
        return array
      end
    end
  end
  
  def read_amf3_object
    type = read_amf3_integer
    isReference = (type & 0x01) == 0
    
    if isReference
      reference = type >> 1
      if reference < @stored_objects.length
        if @stored_objects[reference] == nil
          raise( RUBYAMFException.new(RUBYAMFException.UNDEFINED_OBJECT_REFERENCE_ERROR, "Reference to non existant object at index #{reference}, please tell aaron@rubyamf.org."))
        end
        return @stored_objects[reference]
      else
			  raise( RUBYAMFException.new(RUBYAMFException.UNDEFINED_OBJECT_REFERENCE_ERROR, "Reference to non existant object #{reference}"))
      end
    else
      
      classType = type >> 1
      classIsReference = (classType & 0x01) == 0
      classDefinition = nil
      
      if classIsReference
        classReference = classType >> 1
        if classReference < @stored_defs.length
          classDefinition = @stored_defs[classReference]
        else
  				raise RUBYAMFException.new(RUBYAMFException.UNDEFINED_DEFINITION_REFERENCE_ERROR, "Reference to non existant class definition #{classReference}")
        end
      else
        className = read_amf3_string
        classMembers = []
        externalizable = (classType & 0x02) != 0
        dynamic = (classType & 0x04) != 0
        memberCount = classType >> 3
        
        #Read class members
        0.upto(memberCount - 1) do
          classMembers << read_amf3_string
        end
      
        classDefinition = {"type" => className, "members" => classMembers, "externalizable" => externalizable, "dynamic" => dynamic}
        @stored_defs << classDefinition
        @stored_objects << classDefinition #have to put in stored objects to keep the index count correct
      end
      
      ob = OpenStruct.new #initialize an empty OpenStruct value holder
      
      @stored_objects << ob #add to stored objects first, cicular references are needed.
      type = classDefinition['type'] #get the className according to type
      
      if classDefinition['externalizable']
        if(type == 'flex.messaging.io.ArrayCollection')
          ob = read_amf3
        elsif(type == 'flex.messaging.io.ObjectProxy')
      	  ob = read_amf3
      	else
  				raise( RUBYAMFException.new(RUBYAMFException.USER_ERROR, "Unable to read externalizable data type #{type}"))
      	end
      else
        
        classMembers = classDefinition['members']
        classMembers.each do |key|
          val = read_amf3
          eval("ob.#{key} = val")
        end
      	
      	if classDefinition['dynamic']
      		key = read_amf3_string
          while key != nil && key.length != 0  do
            val = read_amf3
            eval("ob.#{key} = val")
        		key = read_amf3_string #read next key
          end
        end

        #Value Object
        #if type not nil and it is an OpenStruct, check VO Mapping
    		if type != nil && ob.is_a?(OpenStruct)
          ob._explicitType = type #assign the _explictType right away, however if this is a valid VO, it get's changed in VoUtil
          vo = VoUtil.get_vo_for_incoming(ob, type)
          if vo != nil
            return vo
          end
        end
      end
      return ob
    end
	end
  
  def read_amf3_byte_array
    type = read_amf3_integer
    isReference = (type & 0x01) == 0
    if isReference
      reference = type >> 1
      if reference < @stored_objects.length
        if @stored_objects[reference] == nil
          raise( RUBYAMFException.new(RUBYAMFException.UNDEFINED_OBJECT_REFERENCE_ERROR, "Reference to non existant byteArray at index #{reference}, please tell aaron@rubyamf.org"))
        end
        return @stored_objects[reference]
      else
        raise( RUBYAMFException.new(RUBYAMFException.UNDEFINED_OBJECT_REFERENCE_ERROR, "Reference to non existant byteArray #{reference}"))
      end
    else
      length = type >> 1
      ob = readn(length)
      @stored_objects << ob
      return ob
    end
  end
  
  #AMF0	
	def read_number
	  res = read_double
	  if res.to_s == '-Infinity'
	    return NInfinity
	  end
	  res
 	end

 	def read_booleanr
    read_boolean
 	end

 	def read_string
 	  read_utf
 	end

	def read_array
		ret = [] #create new array
		length = read_word32_network # Grab the length of the array
    
    #catch empty arguments
    if(length == nil)
      return []
    end
    
		# Loop over all the elements in the data
		0.upto(length - 1) do
			type = read_byte #Grab the type for each element
			data = read(type) #Grab the element
			ret << data
		end
		ret
	end
  
  def read_date
		# epoch time comes in millis from 01/01/1970, convert to seconds.
		seconds = (read_double) / 1000

		# flash client timezone offset (which comes in minutes, 
		# but incorrectly signed), convert to seconds, and fix the sign.
		client_zone_offset = (read_int16_network) * 60 * -1  # now we have seconds

		# get server timezone offset
		server_zone_offset = Time.zone_offset(Time.now.zone)

		# diff the timezone offset's and subtract from seconds
		# create a time object from the result
		time = Time.at(seconds - server_zone_offset + client_zone_offset)

		# TODO: handle daylight savings 
		#sent_time_zone = sent.get_time_zone
		# we have to handle daylight savings ms as well
		#if (sent_time_zone.in_daylight_time(sent.get_time))
			#sent.set_time_in_millis(sent.get_time_in_millis - sent_time_zone.get_dst_savings)
		#end
		time
	end
	
=begin	#OLD AMF0 VO MAPPING METHOD
	def read_custom_class
		type = read_utf
		load_success = false
		begin
		  c = type.split('.')
  		d = type.split('.').join('/')
		  load(RequestStore.vo_path + '/' + (d + '.rb'))
		  klazz = Object.const_get(c[1]).new
		  load_success = true
		rescue Exception => e
		  load_sucess = false
		end
    
		value = read_object
		
		if load_success #if loaded VO object successfully, return a new instance of that VO class
		  members = value.marshal_dump.keys.map{|k| k.to_s}
		  members.each do |k|
		    v = eval "value.#{k}"
		    klazz.instance_variable_set("@#{k}", v)
		  end
		  klazz.rmembers = members
		  klazz._explicitType = type
		  return klazz
		end
	  value #if VO not loaded correctly, returns a standard Object
	end	
=end

  #Reads and instantiates a custom incoming ValueObject
  def read_custom_class
  	type = read_utf
  	value = read_object
	
  	#Value Object
    #if type not nil and it is an OpenStruct, check VO Mapping
  	if type != nil && ob.is_a?(OpenStruct)
      ob._explicitType = type #assign the _explictType right away, however if this is a valid VO, it get's changed in VoUtil
      vo = VoUtil.get_vo_for_incoming(ob, type)
      if vo != nil
        return vo #prematurly return the new VO
      end
    end
    value #return value if no VO was created
  end

  #reads a mixed array
  def read_mixed_array
    ash = Hash.new
    key = read_utf
    type = read_byte
    while(type != 9)
      value = read(type)
      ash[key] = value
      key = read_utf
      type = read_byte
    end
    ash
  end

  def read_object
	  aso = OpenStruct.new
	  amf0_object_default_members_ignore = []
	  if(!@in_headers)
	    amf0_object_default_members_ignore = ['Credentials','coldfusion','amfheaders','amf','httpheaders','recordset','error','trace','m_debug']
	  end
		key = read_utf #read the value's key
		type = read_byte #read the value's type
		while (type != 9) do
			value = read(type)
			if !amf0_object_default_members_ignore.include?(key) && !value.nil?
				eval "aso.#{key} = value"
			end
			key = read_utf # Read the next key
			type = read_byte # Read the next type
		end
		return aso
	end
  
	def read_xml
		read_long_utf
	end
end
end
end