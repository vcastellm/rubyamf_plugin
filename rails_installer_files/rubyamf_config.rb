require 'app/configuration'
module RubyAMF
  module Configuration
    #set the service path used in all requests
    # RubyAMF::App::RequestStore.service_path = File.expand_path(RAILS_ROOT) + '/app/controllers'

    # => CLASS MAPPING CONFIGURATION
    
    # => Global Property Ignoring
    # By putting attribute names into this array, you opt in to globally ignore these properties on incoming objects.
    # If you want to ignore specific properties on certain objects, use the :ignore_fields property in a 
    # Class Mapping definition (see CLASS MAPPING DEFINITIONS)
    # ClassMappings.ignore_fields = ['created_at','created_on','updated_at','updated_on']
  
    # => Case Translations
    # Most actionscript uses camelCase instead of snake_case. Set ClassMappings.translate_case to true if want translations to occur.
    # The translations only occur on object properties
    # An incoming property like: myProperty gets turned into my_property
    # An outgoing property like my_property gets turned into myProperty
    #ClassMappings.translate_case = false
  
    # => Force Active Record Ids
    # includes the id field for activerecord objects even if you don't specify it when using custom attributes. This is important for deserialization
    # where ids are needed to keep active record association integrity.
    # ClassMappings.force_active_record_ids = true
    
    # => Hash key access
    # You can choose how keys in hashes are created. As :string, :symbol, or :indifferent. 
    # :string creates keys as hash['key']
    # :symbol creates keys as hash[:key]
    # :indifferent uses rails HashWithIndifferentAccess so you can use hash[:key] of hash['key']
    # There are performance issues with HashWithIndifferentAccess. Use :symbol or :string for best performance.
    # The default is :symbol
    # ClassMappings.hash_key_access = :symbol
    
    # => Assume Class Types
    # This tells RubyAMF to assume class type transfers. So when you register a class Alias from Flash or Flex like this:
    # Flash::   fl.net.registerClassAlias('User',User)
    # Flex::    [RemoteClass(alias='User')]
    # RubyAMF will automagically convert it to a User active record without you having to create a class mapping.
    # This also works with non active record class mappings. See the wiki on the google code page for a downloadable example.
    # ClassMappings.assume_types = false
    
    # => Class Mapping Definitions
    # A Class Mapping definition conists of at least these two properties:
    # :actionscript   # The incoming action script class to watch for
    # :ruby           # The ruby class to turn it into
    #
    # => Optional value object properties:
    # :type           # Used to spectify the type of VO, valid options are 'active_record', 'custom',  (or don't specify at all)
    # :associations   # Specify which associations to read on the active record (only applies to active records)
    # :attributes     # Specifically which attributes to include in the serialization
    # :methods        # An array of methods to call and place values in a similarly named attribute on the Actionscript Object (outgoing, or Rails => Actionscript only)
    # :ignore_fields  # An array of field names you want to ignore on incoming classes
    #
    # If you are using ActiveRecord VO's you do not need to specify a fully qualified class path to the model, you can just define the class name, 
    # EX: ClassMappings.register(:actionscript => 'vo.Person', :ruby => 'Person', :type => 'active_record')
    #
    # If you are using custom VO's you would need to specify the fully qualified class path to the file
    # EX: ClassMappings.register(:actionscript => 'vo.Person', :ruby => 'org.mypackage.Person')
    #
    # ClassMappings.register(:actionscript => 'Person', :ruby => 'Person', :type => 'active_record', :attributes => ["id", "address_id"])
    # ClassMappings.register(:actionscript => 'User', :ruby => 'User', :type => 'active_record', :associations=> ["addresses", "credit_cards"])
    # ClassMappings.register(:actionscript => 'Address', :ruby => 'Address', :type => 'active_record')
    # ClassMappings.register(:actionscript => 'User', :ruby => 'User', :type => 'active_record', :associations=> ["addresses", "credit_cards"], :methods => ["friends"])
    #
    # => Class Mapping Scope (Advanced Usage)
    # You can also specify a class mapping scope if you want. For example, lets say you need certain attributes for a book when you are viewing a book
    # in flex as opposed to editing a book (where you would need more parameters). You can define a scope mapping parameter for ":attributes"
    # or for ":associations." You're mapping would look something like this.
    # ClassMappings.register(
    #   :actionscript  => 'com.mixbook.vo.books.BookVO',      
    #   :ruby          => 'Book',      
    #   :type          => 'active_record',
    #   :associations  => ["access_info", "pages", "page_ratio"],  
    #   :attributes    => {:viewing => ["description", "title"], :editing => ["id","published_at","theme_id"] }    <=== notice the hash instead of an array
    #
    # Now, to call the class mapping scope of editing (you are sending objects to the editing application), your controller call would look like this:
    # EX: render :amf => book, :class_mapping_scope => :editing
    #
    # You can also specify a default scope to use. If you don't set this and you don't specify a class mapping scope on an attribute or association, then 
    # it will not have a scope to use and will not add any attributes or associations (whichever it cant match) to that association.
    # ClassMappings.default_mapping_scope = :viewing
  
    # => Date Conversion
    # Incoming dates from Flash by default are Time objects, this can conver to DateTime if needed
    # ClassMappings.use_ruby_date_time = false
  
    # => Use Array Collection
    # By setting this to true, you opt in to using array collections for all the arrays generated by the body of your request.
    # Note: This only works for amf3 with Remote Object, NOT with Net Connection.
    # ClassMappings.use_array_collection = false
  
    # => Check for Associations
    # Enabling this will automagically pick up eager loaded association data on objects returned through RubyAMF.
    # If this is disabled, you will need to specify any associations you DO want picked up in the ClassMapping
    # ClassMappings.check_for_associations = true
    
    # => NAMED PARAMETER MAPPING CONFIGURATION
    
    #=> Always Put Remoting Parameters into the "params" hash
    # If set to true, arguments from Flash/Flex will come in to the controllers as params[0], params[1], etc.. This is especally useful if you are sending huge objects
    # from Flex into Ruby so it doesnt eat up all your output window with outputting the params in the controller/action header information while in dev mode.
    # Even if its set to false, if you specify specific ParameterMappings, those will still get entered as the param keys you specify. Likewise, you
    # always have access to the parameters from rubyamf in your controller by calling rubyamf_params[0], rubyamf_params[1], etc regardless of
    # if it this is set or not.
    # ParameterMappings.always_add_to_params = true
     
    # => Return Top Level Hash
    # For those scaffolding users out there, who want the top-level object to come as a hash so scaffolding works out of the box.
    # ParameterMappings.scaffolding = false
  
    # => Incoming Remoting Parameter Mappings
    # Incoming Remoting Parameter mappings allow you to map an incoming requests parameters into rails' params hash
    #
    # Here's an example:
    # ParameterMappings.register(:controller => :UserController, :action => :find_friend, :params => { :friend => "[0]['friend']" })
  end
end