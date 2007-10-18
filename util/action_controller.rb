#decorate ActionController::Base for render :amf
ActionController::Base.class_eval do
  def render_with_amf(options = nil, &block)
    begin
      if options != nil && options.keys.include?(:amf)
        #store results on RequestStore, can't prematurely return or send_data.
        RequestStore.render_amf_results = options[:amf]
      else
        render_without_amf(options,&block)
      end
    rescue Exception => e
      #suppress missing template warnings
      raise e if !e.message.match(/^Missing template/)
    end
  end
  alias_method_chain :render, :amf
end

#This class extends ActionController::Base
class ActionController::Base
  
  attr_accessor :is_amf
  attr_accessor :is_rubyamf #-> for simeon :)-
  attr_accessor :used_render_amf
  attr_accessor :amf_content
  attr_accessor :rubyamf_attempt_file_render
  
  #Higher level "credentials" method that returns credentials wether or not 
  #it was from setRemoteCredentials, or setCredentials
  def credentials
    empty_auth = {:username => nil, :password => nil}
    a = amf_credentials
    h = html_credentials
    if !a.nil?
      return a
    elsif !h.nil?
      return h
    end
    empty_auth #return an empty auth, this watches out for being the cause of an exception, (nil[])
  end
  
private
  #setCredentials access
  def amf_credentials
    auth = RequestStore.rails_authentication
    if(!auth)
      return nil
    else
      if !auth[:username] && !auth[:password]
        return nil
      end
    end
    return auth
  end
  
  #remoteObject setRemoteCredentials retrieval
  def html_credentials
    auth_data = request.env['RAW_POST_DATA']
    auth_data = auth_data.scan(/DSRemoteCredentials.*?\001/)
    if auth_data.size > 0
      auth_data = auth_data[0][21, auth_data[0].length-22]
      remote_auth = Base64.decode64(auth_data).split(':')[0..1]
    else
      return nil
    end
    return {:username => remote_auth[0], :password => remote_auth[1]}
  end  
end