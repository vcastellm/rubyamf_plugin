#Copyright (c) 2007 Aaron Smith (aaron@rubyamf.org) - MIT License

require 'rubygems'
require 'active_record'
require 'yaml'

#This is a simple module to do ActiveRecord initialization for you,
#include this module in your service and call ar_connect("some_yaml_file.yaml", "yaml_connection_node")
#the yaml connection node corresponds to the node in yaml you want to use for the connection

=begin

YAML FILE: ---services/some/package/my.yaml
___________
myconnectionnode:
  adapter: "mysql"
  host: "localhost"
  username: "root"
  password: ""
  database: "mydatabase"
___________

#Service EX:
SERVICE FILE: ---services/some/package/MyService.rb
___________
require RUBYAMF_SERVICES + 'rubyamf/helpers/active_record_connector'
class MyService
  include ActiveRecordConnector
  def before_filter
    ar_connect(RUBYAMF_SERVICES + 'some/paackage/my.yaml','myconnectionnode')
  end
end
___________

##NOTE That the default connection YAML node is "development"

=end

module ActiveRecordConnector
  def ar_connect(yml,node = "development")
    begin
      pt = RUBYAMF_SERVICES + yml
      db = ''
      File.open(pt,'r') { |f|
        db = YAML.load(f)
      }      
      ActiveRecord::Base.establish_connection(
      {
        :adapter  => db[node]["adapter"],
        :host     => db[node]["host"],
        :username => db[node]["username"],
        :password => db[node]["password"],
        :database => db[node]["database"]
      })
    rescue Exception => e
      puts e.message
      raise e
    end
  end  
end