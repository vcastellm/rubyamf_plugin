require 'app/request_store'

begin
  
  Native = :Native
  Big = BigEndian = Network = :BigEndian
  Little = LittleEndian = :LittleEndian

  module RUBYAMF
  module IO
  module BinaryReader
  
    #examines the locale byte order on the running machine
    def byte_order
      if [0x12345678].pack("L") == "\x12\x34\x56\x78" 
        BigEndian
      else
        LittleEndian
      end
    end
  
    def byte_order_little?
      (byte_order == :LittleEndian) ? true : false;
    end
  
    def byte_order_big?
      (byte_order == :BigEndian) ? true : false;
    end
    alias :byte_order_network? :byte_order_big?
  
    #read N length from stream starting at position
    def readn(length)
    	self.stream_position ||= 0
  		str = self.stream[self.stream_position, length]
  		self.stream_position += length
  		str
    end
  
    #reada a boolean
    def read_boolean
      d = self.stream[self.stream_position,1].unpack('c').first
      self.stream_position += 1
      (d == 1) ? true : false;
    end
  
    #8bits no byte order
    def read_int8
      d = self.stream[self.stream_position,1].unpack('c').first
      self.stream_position += 1
      d
    end
    alias :read_byte :read_int8  
  
    def read_word8
      begin
        d = self.stream[self.stream_position,1].unpack('C').first
        self.stream_position += 1
        d
      rescue Exception => e
        #This is a fix for rails' ActionPack. It was choping off the last \000 byte
        if (e.message =~ /unpack/ && e.message =~ /nil/) && RequestStore.rails == true
          return "\000".unpack('C').first
        else
          raise
        end
      end
    end
  
    #16 bits Unsigned
    def read_word16_native
      d = self.stream[self.stream_position,2].unpack('S').first
      self.stream_position += 2
      d
    end
  
    def read_word16_little
      d = self.stream[self.stream_position,2].unpack('v').first
      self.stream_position += 2
      d
    end

    def read_word16_network
      d = self.stream[self.stream_position,2].unpack('n').first
      self.stream_position += 2
      d
    end
  
    #16 bits Signed
    def read_int16_native
      str = self.readn(2).unpack('s').first
    end
  
    def read_int16_little
      str = self.readn(2)
      str.reverse! if byte_order_network? # swap bytes as native=network (and we want little)
      str.unpack('s').first
    end
  
    def read_int16_network
      str = self.readn(2)
      str.reverse! if byte_order_little? # swap bytes as native=little (and we want network)
      str.unpack('s').first
    end
  
    #32 bits unsigned
    def read_word32_native
      d = self.stream[self.stream_position,4].unpack('L').first
      self.stream_position += 4
      d
    end

    def read_word32_little
      d = self.stream[self.stream_position,4].unpack('V').first
      self.stream_position += 4
      d
    end
  
    def read_word32_network
      d = self.stream[self.stream_position,4].unpack('N').first
      self.stream_position += 4
      d
    end
  
    #32 bits signed
    def read_int32_native
      d = self.stream[self.stream_position,4].unpack('l').first
      self.stream_position += 4
      d
    end
  
    def read_int32_little
      str = readn(4)
      str.reverse! if byte_order_network? # swap bytes as native=network (and we want little)
      str.unpack('l').first
    end
  
    def read_int32_network
      str = readn(4)
      str.reverse! if byte_order_little? # swap bytes as native=little (and we want network)
      str.unpack('l').first
    end
  
  
    #UTF string
    def read_utf
  		length = self.read_word16_network
  		readn(length)
    end
  
    def read_int32_network
      str = self.readn(4)
      str.reverse! if byte_order_little? # swap bytes as native=little (and we want network)
      str.unpack('l').first
    end
  
    def read_double
      d = self.stream[self.stream_position,8].unpack('G').first
      self.stream_position += 8
      d
    end
  
    def read_long_utf(length)
  		length = read_word32_network #get the length of the string (1st 4 bytes)
  		self.readn(length) #read length number of bytes
    end
  end


  module BinaryWriter
  
    #examines the locale byte order on the running machine
    def byte_order
      if [0x12345678].pack("L") == "\x12\x34\x56\x78" 
        BigEndian
      else
        LittleEndian
      end
    end
  
    def byte_order_little?
      (byte_order == :LittleEndian) ? true : false;
    end
  
    def byte_order_big?
      (byte_order == :BigEndian) ? true : false;
    end
    alias :byte_order_network? :byte_order_big?
  
    def writen(val)
      self.stream << val
    end
  
    #8 bit no byteorder
    def write_word8(val)
      self.stream << [val].pack('C')
    end

    def write_int8(val)
      self.stream << [val].pack('c')
    end

    #16 bit unsigned
    def write_word16_native(val)
      self.stream << [val].pack('S')
    end
  
    def write_word16_little(val)
      str = [val].pack('S')
      str.reverse! if byte_order_network? # swap bytes as native=network (and we want little)
      self.stream << str
    end
  
    def write_word16_network(val)
      str = [val].pack('S')
      str.reverse! if byte_order_little? # swap bytes as native=little (and we want network)
      self.stream << str
    end
  
    #16 bits signed
    def write_int16_native(val)
      self.stream << [val].pack('s')
    end

    def write_int16_little(val)
      self.stream << [val].pack('v')
    end

    def write_int16_network(val)
      self.stream << [val].pack('n')
    end

    #32 bit unsigned
    def write_word32_native(val)
      self.stream << [val].pack('L')
    end

    def write_word32_little(val)
      str = [val].pack('L')
      str.reverse! if byte_order_network? # swap bytes as native=network (and we want little)
      self.stream << str
    end

    def write_word32_network(val)
      str = [val].pack('L')
      str.reverse! if byte_order_little? # swap bytes as native=little (and we want network)
      self.stream << str
    end

    #32 signed
    def write_int32_native(val)
      self.stream << [val].pack('l')
    end
	
    def write_int32_little(val)
      self.stream << [val].pack('V')
    end

    def write_int32_network(val)
      self.stream << [val].pack('N')
    end
  
    # write utility methods
  	def write_byte(val)
  		self.write_int8(val)
  	end

  	def write_boolean(val)
  		if val then self.write_byte(1) else self.write_byte(0) end
  	end

  	def write_utf(str)
  		self.write_int16_network(str.length)
  		self.stream << str
  	end
  
  	def write_long_utf(str)
  		self.write_int32_network(str.length)
  		self.stream << str
  	end
		
  	def write_double(val)
  		self.stream << [val].pack('G')
  	end
  end
  end
  end
rescue Exception => e
  raise RUBYAMFException.new(RUBYAMFException.AMF_ERROR, "The AMF data is incorrect or incomplete.")
end
