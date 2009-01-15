require 'app/request_store'
require 'app/configuration'
ActionController::Base.class_eval do
  def render_with_amf(options = nil, &block)
    begin
      if options && options.is_a?(Hash) && options.keys.include?(:amf)
        #set the @performed_render flag to avoid double renders
        @performed_render = true
        #store results on RequestStore, can't prematurely return or send_data.
        RubyAMF::App::RequestStore.render_amf_results = options[:amf]
        RubyAMF::Configuration::ClassMappings.current_mapping_scope = options[:class_mapping_scope]||RubyAMF::Configuration::ClassMappings.default_mapping_scope
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
  attr_accessor :rubyamf_params # this way they can always access the rubyamf_params
  
  #Higher level "credentials" method that returns credentials wether or not
  #it was from setRemoteCredentials, or setCredentials
  def credentials
    empty_auth = {:username => nil, :password => nil}
    amf_credentials||html_credentials||empty_auth #return an empty auth, this watches out for being the cause of an exception, (nil[])
  end
  
private
  #setCredentials access
  def amf_credentials
    RubyAMF::App::RequestStore.rails_authentication
  end
  
  #remoteObject setRemoteCredentials retrieval
 def html_credentials
    auth_data = request.env['RAW_POST_DATA']
    auth_data = auth_data.scan(/DSRemoteCredentials\006.([A-Za-z0-9\+\/=]*).*?\006/)[0][0]
    auth_data.gsub!("DSRemoteCredentialsCharset", "")
    if auth_data.size > 0

      remote_auth = Base64.decode64(auth_data).split(':')[0..1]
    else
      return nil
    end
    case RubyAMF::Configuration::ClassMappings.hash_key_access
    when :string:
      return {'username' => remote_auth[0], 'password' => remote_auth[1]}
    when :symbol:
      return {:username => remote_auth[0], :password => remote_auth[1]}
    when :indifferent:
      return HashWithIndifferentAccess.new({:username => remote_auth[0], :password => remote_auth[1]})
    end
  end
end