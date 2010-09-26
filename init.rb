$:.unshift(File.expand_path(Rails::VERSION::MAJOR < 3 ? RAILS_ROOT : ::Rails.root.to_s) + '/vendor/plugins/rubyamf_plugin/') #fosrias: RAILS_ROOT deprectated in Rails 3

#utils must be first
require 'util/string'
require 'util/vo_helper'
require 'util/active_record'
require 'util/action_controller'
require 'app/mime_type'
require 'app/fault_object'
require 'app/rails_gateway'
require File.expand_path(Rails::VERSION::MAJOR < 3 ? RAILS_ROOT : ::Rails.root.to_s) + '/config/rubyamf_config' #run the configuration, fosrias: RAILS_ROOT deprectated in Rails 3


