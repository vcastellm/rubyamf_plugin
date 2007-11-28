module RubyAMF
  module IO
    class AMFDeserializer
      
      require 'io/read_write'
      
      include RubyAMF::AMF
      include RubyAMF::App
      include RubyAMF::Configuration
      include RubyAMF::Exceptions
      include RubyAMF::IO::BinaryReader
      include RubyAMF::IO::Constants
      include RubyAMF::VoHelper
      attr_accessor :stream
      attr_accessor :stream_position      
      attr_accessor :amf0_object_default_members_ignore
      
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
        preamble
        headers
        bodys
      end
      
      def reset_referencables
        @amf0_stored_objects = []
        @amf0_object_default_members_ignore = {}
        @class_member_defs = {}
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
      end
      
      def headers
        @amf0_object_default_members_ignore = {
          'Credentials' => true,
          'coldfusion'  => true,
          'amfheaders'  => true,
          'amf'         => true,
          'httpheaders' => true,
          'recordset'   => true,
          'error'       => true,
          'trace'       => true,
          'm_debug'     => true}
        
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
        @amf0_object_default_members_ignore = {}
        
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
        case type
        when AMF3_TYPE
          RequestStore.amf_encoding = 'amf3'
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
          return nil
        when AMF_UNDEFINED
          return nil
        when AMF_REFERENCE
          return nil #TODO Implement this
        when AMF_MIXED_ARRAY
          length = read_int32_network #long, don't do anything with it
          read_mixed_array
        when AMF_EOO
          return nil
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
        b = read_word8||0
        result = 0
        
        while ((b & 0x80) != 0 && n < 3)
          result = result << 7
          result = result | (b & 0x7f)
          b = read_word8||0
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
          if (result > AMF3_INTEGER_MAX)
            result -= (1 << 29)
          end
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
        length = type >> 1
        readn(length)
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
          seconds = read_double.to_f/1000
          time = if (seconds < 0) || ClassMappings.use_ruby_date_time # we can't use Time if its a negative second value
            DateTime.strptime(seconds.to_s, "%s")
          else 
            Time.at(seconds)
          end
          @stored_objects << time
          time
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
            @stored_objects << array
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
          else
            array = []
            @stored_objects << array
            0.upto(length - 1) do
              array << read_amf3
            end
          end
          array
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
          
          class_type = type >> 1
          class_is_reference = (class_type & 0x01) == 0
          
          if class_is_reference
            class_reference = class_type >> 1
            if class_reference < @stored_defs.length
              class_definition = @stored_defs[class_reference]
            else
              raise RUBYAMFException.new(RUBYAMFException.UNDEFINED_DEFINITION_REFERENCE_ERROR, "Reference to non existant class definition #{class_reference}")
            end
          else
            actionscript_class_name = read_amf3_string
            externalizable = (class_type & 0x02) != 0
            dynamic = (class_type & 0x04) != 0
            attribute_count = class_type >> 3
            
            class_attributes = []
            attribute_count.times{class_attributes << read_amf3_string} # Read class members
            
            class_definition = {"as_class_name" => actionscript_class_name, "members" => class_attributes, "externalizable" => externalizable, "dynamic" => dynamic}
            @stored_defs << class_definition
          end
          action_class_name = class_definition['as_class_name'] #get the className according to type
          
          # check to see if its the first main amf object or a flex message obj, because then we need a _explicitType field type and skip some things
          skip_mapping = if action_class_name && action_class_name.include?("flex.messaging")
            obj = VoHash.new # initialize an empty VoHash value holder    
            obj._explicitType = action_class_name
            true
          else # otherwise just use a normal hash
            obj = {}
            false
          end
            
          obj_position = @stored_objects.size # need to replace the object later for referencing (MUST be before inserting the object into stored_objs)
          @stored_objects << obj
          
          
          if class_definition['externalizable']
            if ['flex.messaging.io.ObjectProxy','flex.messaging.io.ArrayCollection'].include?(action_class_name)
              obj = read_amf3
            else
              raise( RUBYAMFException.new(RUBYAMFException.USER_ERROR, "Unable to read externalizable data type #{type}"))
            end            
          else            
            translate_case = !skip_mapping&&ClassMappings.translate_case  # remove the need for a method call / also, don't want to convert on main remoting object
            class_definition['members'].each do |key|
              value = read_amf3
              #if (value)&& value != 'NaN'# have to read key to move the reader ahead in the stream
              key.to_snake! if translate_case   
              obj[key] = value
              #end
            end
            
            if class_definition['dynamic']
              while (key = read_amf3_string) && key.length != 0  do # read next key
                value = read_amf3
                #if (value) && value != 'NaN'
                key.to_snake! if translate_case  
                obj[key] = value
                #end
              end
            end
            obj = VoUtil.get_vo_for_incoming(obj,action_class_name) unless skip_mapping
          end
          @stored_objects[obj_position] = obj # put the new object into the same position as the original object since it was worked on
          obj
        end
      end
      
      def read_amf3_byte_array # according to the charles amf3 deserializer, they store byte array
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
          begin # first assume its gzipped and rescue an exception if its not
            inflated_stream = Zlib::Inflate.inflate( self.stream[self.stream_position,length] )
            arr = inflated_stream.unpack('c'*inflated_stream.length) 
          rescue Exception => e
            arr = self.stream[self.stream_position,length].unpack('c'*length)
          end      
          self.stream_position += length
          @stored_objects << arr
          arr
        end
      end
      
      #AMF0  
      def read_number
        res = read_double
        res.is_a?(Float)&&res.nan? ? nil : res # check for NaN and convert them to nil
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
        if !length
          return []
        end

        #Loop over all the elements in the data
        0.upto(length - 1) do
          type = read_byte #Grab the type for each element
          data = read(type) #Grab the element
          ret << data
        end
        ret
      end

      def read_date
        #epoch time comes in millis, convert to seconds.
        seconds = read_double.to_f / 1000

        #flash client timezone offset (which comes in minutes, 
        #but incorrectly signed), convert to seconds, and fix the sign.
        client_zone_offset = (read_int16_network) * 60 * -1  # now we have seconds

        #get server timezone offset
        server_zone_offset = Time.zone_offset(Time.now.zone)

        # adjust the timezone with the offsets
        seconds += (client_zone_offset - server_zone_offset)
        
        #TODO: handle daylight savings 
        #sent_time_zone = sent.get_time_zone
        #we have to handle daylight savings ms as well
        #if (sent_time_zone.in_daylight_time(sent.get_time))
        #sent.set_time_in_millis(sent.get_time_in_millis - sent_time_zone.get_dst_savings)
        #end
        
        #diff the timezone offset's and subtract from seconds
        #create a time object from the result
        if (seconds < 0) || ClassMappings.use_ruby_date_time # we can't use Time if its a negative second value
          DateTime.strptime(seconds.to_s, "%s")
        else 
          Time.at(seconds)
        end
      end

      #Reads and instantiates a custom incoming ValueObject
      def read_custom_class
        type = read_utf
        value = read_object
        #if type not nil and it is an VoHash, check VO Mapping
        if type && value.is_a?(VoHash)
          vo = VoUtil.get_vo_for_incoming(value,type)
          value = vo
        end
        value #return value if no VO was created
      end

      #reads a mixed array
      def read_mixed_array
        mix_array = Hash.new
        key = read_utf
        type = read_byte
        while(type != 9)
          value = read(type)
          mix_array[key] = value
          key = read_utf
          type = read_byte
        end
        mix_array
      end

      def read_object
        obj = VoHash.new
        key = read_utf #read the value's key
        type = read_byte #read the value's type
        while (type != 9) do
          value = read(type)
          key.to_snake! if ClassMappings.translate_case
          obj[key] = value
          key = read_utf # Read the next key
          type = read_byte # Read the next type
        end
        obj
      end

      def read_xml
        read_long_utf
      end
    end
  end
end
