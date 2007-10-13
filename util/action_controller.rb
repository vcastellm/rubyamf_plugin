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
  
  def render(options = nil, deprecated_status = nil, &block)
    raise DoubleRenderError, "Can only render or redirect once per action" if performed?
    begin
      if self.is_amf
        #nothing
      elsif options.nil?
        return render_file(default_template_name, deprecated_status, true)
      else
        #Backwards compatibility
        unless options.is_a?(Hash)
          if options == :update
            options = { :update => true }
          else
            ActiveSupport::Deprecation.warn(
              "You called render('#{options}'), which is a deprecated API call. Instead you use " +
              "render :file => #{options}. Calling render with just a string will be removed from Rails 2.0.",
              caller
            )
            return render_file(options, deprecated_status, true)
          end
        end
      end

      if content_type = options[:content_type]
        response.content_type = content_type.to_s
      end

      if text = options[:text]
        render_text(text, options[:status])

      else
        if file = options[:file]
          render_file(file, options[:status], options[:use_full_path], options[:locals] || {})

        elsif template = options[:template]
          render_file(template, options[:status], true)

        elsif inline = options[:inline]
          render_template(inline, options[:status], options[:type], options[:locals] || {})

        elsif action_name = options[:action]
          ActiveSupport::Deprecation.silence do
            render_action(action_name, options[:status], options[:layout])
          end

        elsif xml = options[:xml]
          render_xml(xml, options[:status])

        elsif json = options[:json]
          render_json(json, options[:callback], options[:status])
        
        elsif amf = options[:amf]
          self.used_render_amf = true
          self.amf_content = amf

        elsif partial = options[:partial]
          partial = default_template_name if partial == true
          if collection = options[:collection]
            render_partial_collection(partial, collection, options[:spacer_template], options[:locals], options[:status])
          else
            render_partial(partial, ActionView::Base::ObjectWrapper.new(options[:object]), options[:locals], options[:status])
          end

        elsif options[:update]
          add_variables_to_assigns
          @template.send :evaluate_assigns

          generator = ActionView::Helpers::PrototypeHelper::JavaScriptGenerator.new(@template, &block)
          render_javascript(generator.to_s)

        elsif options[:nothing]
          # Safari doesn't pass the headers of the return if the response is zero length
          render_text(" ", options[:status])

        else
          render_file(default_template_name, options[:status], true)
        end
      end
    rescue NoMethodError => e
      if self.is_amf
        return
      else
        raise
      end
    end
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