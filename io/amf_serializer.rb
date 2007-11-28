module RubyAMF
  module IO
    class AMFSerializer

      require 'io/read_write'

      include RubyAMF::AMF
      include RubyAMF::Configuration
      include RubyAMF::App
      include RubyAMF::IO::BinaryWriter
      include RubyAMF::IO::Constants
      include RubyAMF::VoHelper
      attr_accessor :stream

      def initialize(amfobj)
        @amfobj = amfobj
        @stream = @amfobj.output_stream #grab the output stream for the amfobj
      end
   
      def reset_referencables
        @amf0_stored_objects = []
        @stored_strings = {} # hash is way faster than array
        @stored_strings[""] = true # add this in automatically
        @floats_cache = {}
        @write_amf3_integer_results = {} # cache the integers
        @current_strings_index = 0
      end
   
      def run
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
        if RequestStore.amf_encoding == 'amf3'
          write_byte(AMF3_TYPE)
          write_amf3(value)
          
        elsif value == nil
          @stream << "\005" #write_null
      
        elsif (value.is_a?(Numeric))
          write_number(value)
       
        elsif (value.is_a?(String))
          write_string(value)

        elsif (value.is_a?(TrueClass) || value.is_a?(FalseClass))
          (value) ? @stream << "\001" : @stream << "\000"
    
        elsif value.is_a?(ActiveRecord::Base) # Aryk: this way, we can bypass the next four checks most of the time
          write_object(VoUtil.get_vo_hash_for_outgoing(value))
    
        elsif(value.is_a?(VoHash))
          write_object(value)
    
        elsif (value.is_a?(Array))
          write_array(value)

        elsif (value.is_a?(Hash))
          write_hash(value)

        elsif (value.is_a?(Date))
          write_date(value.strftime("%s").to_i) # Convert a Date into a time object
      
        elsif (value.is_a?(Time))
          write_date(value.to_f)
       
        elsif value.class.to_s == 'REXML::Document'
          write_xml(value.write.to_s)
         
        elsif (value.class.to_s == 'BeautifulSoup')
          write_xml(value.to_s)
        else
          write_object(VoUtil.get_vo_hash_for_outgoing(value))
        end
      end

      #AMF3
      def write_amf3(value)
        if !value
          @stream << "\001" # represents an amf3 null
      
        elsif (value.is_a?(TrueClass) || value.is_a?(FalseClass))
          value ? (@stream << "\003")  : (@stream << "\002")   # represents an amf3 true  and  false
      
        elsif value.is_a?(Numeric)
          if value.is_a?(Integer) # Aryk: This was also incorrect before because you has Bignum check AFTER the Integer check, which means the Bignum's were getting picked up by Integers
            if value.is_a?(Bignum)
              @stream << "\005" # represents an amf3 complex number
              write_double(value)
            else
              write_amf3_number(value)
            end
          elsif(value.is_a?(Float))
            @stream << "\005" # represents an amf3 complex number
            write_double(value)
          elsif value.is_a?(BigDecimal) # Aryk: BigDecimal does not relate to Float, so keep it as a seperate check.
            # TODO: Aryk: Not quite sure why you do value.to_s.to_f? can't you just do value.to_f?
            value = value.to_s('F').to_f #this is turning a string into a Ruby Float, but because there are no further operations on it it is safe          
            @stream << "\005" # represents an amf3 complex number
            write_double(value)
          end
    
        elsif(value.is_a?(String))
          @stream << "\006" # represents an amf3 string
          write_amf3_string(value)
         
        elsif(value.is_a?(Array))
          write_amf3_array(value)
    
        elsif(value.is_a?(Hash))
          write_amf3_object(value)
  
        elsif (value.is_a?(Time)||value.is_a?(Date))
          @stream << "\b" # represents an amf3 date
          write_amf3_date(value)
      
          # I know we can combine this with the last condition, but don't  ; the Rexml and Beautiful Soup test is expensive, and for large record sets with many AR its better to be able to skip the next step
        elsif value.is_a?(ActiveRecord::Base) # Aryk: this way, we can bypass the "['REXML::Document', 'BeautifulSoup'].include?(value.class.to_s) " operation
          write_amf3_object(VoUtil.get_vo_hash_for_outgoing(value))
      
        elsif ['REXML::Document', 'BeautifulSoup'].include?(value.class.to_s) 
          write_byte(AMF3_XML)
          write_amf3_xml(value)

        elsif value.is_a?(Object)
          write_amf3_object(VoUtil.get_vo_hash_for_outgoing(value) )
        end
      end
  
      def write_amf3_integer(int)
        @stream << (@write_amf3_integer_results[int] ||= (
            int = int & 0x1fffffff
            if(int < 0x80)
              [int].pack('c')
            elsif(int < 0x4000)
              [int >> 7 & 0x7f | 0x80].pack('c')+
                [int & 0x7f].pack('c')
            elsif(int < 0x200000)
              [int >> 14 & 0x7f | 0x80].pack('c')+
                [int >> 7 & 0x7f | 0x80].pack('c')+
                [int & 0x7f].pack('c')
            else
              [int >> 22 & 0x7f | 0x80].pack('c')+
                [int >> 15 & 0x7f | 0x80].pack('c')+
                [int >> 8 & 0x7f | 0x80].pack('c')+
                [int & 0xff].pack('c')
            end
          ))
      end
  
      def write_amf3_number(number)
        if(number >= AMF3_INTEGER_MIN && number <= AMF3_INTEGER_MAX) #check valid range for 29bits
          @stream << "\004" # represents an amf3 integer
          write_amf3_integer(number)
        else #overflow condition otherwise
          @stream << "\005" # represents an amf3 complex number
          write_double(number)
        end
      end
  
      def write_amf3_string(string)
        if index = @stored_strings[string]
          if string == "" # store this initially so it gets caught by the stored_strings check
            @stream << "\001" # represents an amf3 empty string
          else
            reference = index << 1
            write_amf3_integer(reference)
          end
        else
          @stored_strings[string] = @current_strings_index
          @current_strings_index += 1 # increment the index
          reference = string.length
          reference = reference << 1
          reference = reference | 1
          write_amf3_integer(reference)
          writen(string)
        end
      end
    
      def write_amf3_object(hash)   
        not_vo_hash = !hash.is_a?(VoHash) # is this not a vohash - then doesnt have an _explicitType parameter
        @stream << "\n\v" # represents an amf3 object and dynamic object  
        not_vo_hash || !hash._explicitType ? (@stream << "\001") : write_amf3_string(hash._explicitType)
        hash.each do |attr, value| # Aryk: no need to remove any "_explicitType" or "rmember" key since they werent added as keys
          if not_vo_hash # then that means that the attr might not be symbols and it hasn't gone through camelizing if thats needed
            attr = attr.to_s.dup # need this just in case its frozen
            attr.to_camel! if ClassMappings.translate_case 
          end
          write_amf3_string(attr) 
          value ? write_amf3(value) : (@stream << "\001") # represents an amf3 null
        end        
        @stream << "\001" # represents an amf3 empty string #close open object
      end
  
      def write_amf3_array(array)
        num_objects = array.length * 2 + 1
        if ClassMappings.use_array_collection
          @stream << "\n\a" # AMF3_OBJECT and AMF3_XML
          write_amf3_string("flex.messaging.io.ArrayCollection")
        end
        @stream << "\t" # represents an amf3 array
        write_amf3_integer(num_objects)
        @stream << "\001" # represents an amf3 empty string #write empty for string keyed elements here, as it's never allowed from ruby
        array.each{|v| write_amf3(v) }
      end
  
      def write_amf3_date(datetime) # Aryk: Dates will almost never be the same, so turn off the storing_objects
        write_amf3_integer(1)
        seconds = if datetime.is_a?(Time)
          datetime.utc unless datetime.utc?
          datetime.to_f
        elsif datetime.is_a?(Date) # this also handles the case for DateTime
          datetime.strftime("%s").to_i
          # datetime = Time.gm( datetime.year, datetime.month, datetime.day )
          # datetime = Time.gm( datetime.year, datetime.month, datetime.day, datetime.hour, datetime.min, datetime.sec )      
        end
        write_double( (seconds*1000).to_i ) # used to be total_milliseconds = datetime.to_i * 1000 + ( datetime.usec/1000 )
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
  
      #AMF0
      def write_null
        @stream << "\005" #write_byte(5)
      end

      def write_number(numeric)
        @stream << "\000" #write_byte(0)
        write_double(numeric)
      end

      def write_string(string)
        @stream << "\002" #write_byte(2)
        write_utf(string.to_s)
      end

      def write_booleanr(bool)
        @stream << "\001" #write_byte(1)
        (bool) ? @stream << "\001" : @stream << "\000" #write_boolean(bool)    
      end

      def write_date(seconds)
        @stream << "\v" #write_byte(11)
        write_double(seconds * 1000)
        offset = Time.zone_offset(Time.now.zone)
        write_int16_network(offset / 60 * -1)
      end

      def write_array(array)
        @stream << "\n" #write_byte(10)
        write_word32_network(array.length)
        array.each do |el| 
          write(el)
        end
      end

      def write_hash(hash)
        @stream << "\003" #write_byte(3)
        hash.each do |key, value|
          key.to_s.dup.to_camel! if ClassMappings.translate_case
          write_utf(key)
          write(value)
        end
        #write the end object flag 0x00, 0x00, 0x09
        write_int16_network(0)
        @stream << "\t" #write_byte(9)
      end

      def write_object(vohash)
        if vohash.is_a?(VoHash) && vohash._explicitType
          @stream << "\020" #write_byte(16) #custom class
          write_utf(vohash._explicitType)
        else
          @stream << "\003" #write_byte(3)
        end

        vohash.each do |key,val|
          key.to_s.dup.to_camel! if ClassMappings.translate_case
          write_utf(key)
          write(val)
        end

        #write the end object flag 0x00, 0x00, 0x09
        write_int16_network(0)
        @stream << "\t" #write_byte(9)
      end

      def write_xml(xml_string)
        write_byte(AMF_XML)
        write_long_utf(xml_string.to_s)
      end
    end
  end
end