#Copyright (c) 2007 Aaron Smith (aaron@rubyamf.org) - MIT License

#This is a helper to return FaultObjects. Often times there are sitiuations with database logic that requires an "error state"
#to be set in Flash / Flex, but returning false isn't the best because it still get's mapped to the onResult handler, even returning a 
#generic object with some specific keys set, such as ({error:'someError', code:3}). That is still a pain because it gets mapped to
#the onResult function still. So return one of these objects to RubyAMF and it will auto generate a faultObject to return to flash
#so that it maps correctly to the onFault handler.
class FaultObject < Hash
  attr_accessor :code, :message, :faultString, :faultCode
  def initialize(code = 1, message = '')
    super(nil)
    self.code = code
    self.message = message
    self.faultString = message
    self.faultCode = code
  end
end