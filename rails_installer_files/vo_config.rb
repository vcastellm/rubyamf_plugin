##################################
#=> VALUE OBJECT CONFIGURATION
#=> Global and Application Instance Specific
#
#=> A Value Object definition conists of at least these three properties:
# :incoming   #If an incoming value object is an instance of this type, the VO is turned into whatever the :map_to key specifies
# :map_to     #Defines what object to create if an incoming match is made.
#             #If a result instance is the same as the :map_to key, it is sent back to Flex / Flash as an :outgoing
# :outgoing   #The class to send back to Flex / Flash
#
#=> Optional value object properties:
# :type       #Used to spectify the type of VO, valid options are 'active_record', 'custom',  (or don't specify at all)
# :instance   #tells RubyAMF Lite to use this value object only if the incmoing request was under that application instances scope. (this is for RubyAMF Lite only)
#
# If you are using ActiveRecord VO's you do not need to specify a fully qualified class path to the model, you can just define the class name, 
# EX: ValueObjects.register({:incoming => 'Person', :map_to => 'Person', :outgoing => 'Person', :type => 'active_record'})
#
# If you are using custom VO's you would need to specify the fully qualified class path to the file
# EX: ValueObjects.register({:incoming => 'Person', :map_to => 'org.mypackage.Person', :outgoing => 'Person'})
#
#=> RubyAMF Internal Knowledge of your VO's
# If your VO's aren't active_records, there are two instance variables that are injected to your class so that RubyAMF knows what they are.
# '_explicitType' and 'rmembers'. Just a heads up if you inspect a VO. Don't be surprised by those.
#
#ValueObjects.register({:incoming => 'Person', :map_to => 'Person', :outgoing => 'Person', :type => 'active_record'})
#ValueObjects.register({:incoming => 'User', :map_to => 'User', :outgoing => 'User', :type => 'active_record'})
#ValueObjects.register({:incoming => 'Address', :map_to => 'Address', :outgoing => 'Address', :type => 'active_record'})


##################################
#=> CASE TRANSLATIONS
# Most actionscript uses camel case instead of snake case. Set ValueObjects.translate_case to true if want translations to occur.
# An incoming property like: myProperty gets turned into my_property
# An outgoing property like my_property gets turned into myProperty
ValueObjects.translate_case = false


##################################
#=> INCOMING REMOTING PARAMETER MAPPINGS
#
# Incoming Remoting Parameter mappings allow you to map an incoming requests parameters into rails' params hash
# Here's an example:
# Parameter::Map.register({
#   :controller => :UserController,
#   :action => :find_friend,
#   :params => { :friend => "{0}.friend" }
# })
# This example maps the first remoting parameters "friend" property into params[:friend]
# {0} representes an array accessor
# . represents object notation.
# So you could do this: "{0}{0}.users{5}.firstname" and it will take the value 
# from your remoting parameters: [0][0].users[5].firstname