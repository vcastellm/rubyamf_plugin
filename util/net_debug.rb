require 'app/request_store'
include RUBYAMF::App

module RUBYAMF
module Util
  
#NetDebug is used for traces back to the NetConnection Debugger.
class NetDebug
    
  #init
  def initialize
    NetDebug.Traces = []
  end
  
  #This is called at the end of the filter chain,
  #puts the trace headers back into the amfobj
  def run(amfobj)
    headers = amfobj.get_outheaders
    NetDebug.Traces.each do |h|
      headers << h
    end
  end
  
  #add a trace to the output
  def NetDebug.Trace(msg)
    if(RequestStore.net_debug == false || RequestStore.amf_encoding == 'amf3')
      return
    end
    head = AMFHeader.new('trace',0,msg);
    NetDebug.Traces << head
  end
  
  #traces
  def NetDebug.Traces
    return @@trcs
  end
  
  #traces
  def NetDebug.Traces=(v)
    @@trcs = v
  end
  
end
end
end