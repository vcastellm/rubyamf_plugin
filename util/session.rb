require 'app/request_store'
require 'digest/sha1'
require 'digest/md5'
require 'singleton'
require 'exception/rubyamf_exception'
require 'tmpdir'
include RUBYAMF::App
include RUBYAMF::Exceptions
include RUBYAMF::Util

module RUBYAMF
module Sessions

#A simple session class. implements marshaling for object persistance
#the WEBrick::Session class didn't implement object persistance, but CGI::Session does, 
#so this class was created to use in place of both. 
class MarshalSession
	include Singleton
	attr_reader :session_id
public

	#initialize this session, new or load one
	def init(session_id) 
		@session_data = {}
		if(!RequestStore.use_sessions)
	    return
		end
		
		#if no session at this point, that is a problem, raise error
		if session_id == nil || session_id == ''
			session_id = create_new_id
		end
		
		#store the newly created session id
		@session_id = session_id
		
		#make filename
		dir = Dir::tmpdir
		prefix = 'rubyamf_sid'
		suffix = ''
		md5 = Digest::MD5.hexdigest(session_id)[0, 16]
		@path = File.join(dir, prefix + md5 + suffix)
		
		#restore the session (either creates file, or loads session data into the @session_data var
		restore
	end
	
	#get the val for key
	def [](key)
	  if(!RequestStore.use_sessions)
	    return
		end
		
    @session_data[key]
	end
	
	#save the val for key
	def []=(key, value)
	  if(!RequestStore.use_sessions)
	    return
		end
		
		@session_data[key] = value
	end
	
	def inspect
	  @session_data
	end
	
	#save / update the session
	def persist
		if(!RequestStore.use_sessions)
	    return
		end
	  
		begin
			data = Marshal.dump(@session_data)
			File.open(@path, File::CREAT | File::RDWR, 0777) do |f|
				f.puts data
			end
		rescue Exception => e
		end
	end
	
	#close does the same thing as persist, marshal the object
	alias :close :persist
	
	#restore the session
	def restore
		if(!RequestStore.use_sessions)
	    return
		end

		data = ''
		File.open(@path, File::CREAT | File::RDWR, 0777) do |f|
			while line = f.gets
				data << line
			end
		end
		
		begin #catch when a marshl.load doesn't succeed, if doesn't succeed, just make a new session hash
			@session_data = Marshal.load(data)
		rescue ArgumentError => ae
			@session_data = {}
		end
	end
	
	#delete the session
	def delete
		begin
			File.unlink(@path)
		rescue Errno::ENOENT
		end
	end
	
private

  #create a new session id
  def create_new_id
  	md5 = Digest::MD5.new
  	now = Time.now
  	md5.update(now.to_s)
  	md5.update('rubyamf')
  	return md5.hexdigest[0,16]
  end
	
end
end
end