require 'delegate'
require 'singleton'
require 'logger'

module RUBYAMF
module Util

#simple logger class
class Log < DelegateClass(Logger)
 	
 	include Singleton
 	
 	@@level = Logger::FATAL
 	@@filename = STDOUT
 	
 	def initialize
 		super(Logger.new(@@filename))
 		self.level = @@level
 	end
 	
	# Set the log file to be logged to
 	def Log.SetLogFile(logfile)
 		@@filename = logfile
 	end
end
end
end