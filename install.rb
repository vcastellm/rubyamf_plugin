#This Install script is for Rails Plugin Installation. If using the RubyAMF Lite this is not needed.
begin
  require 'fileutils'
  overwrite = true
    
  if !File.exist?('./config/rubyamf_config.rb')
    FileUtils.copy_file("./vendor/plugins/rubyamf/rails_installer_files/rubyamf_config.rb", "./config/rubyamf_config.rb", false)
  end
  
  FileUtils.copy_file("./vendor/plugins/rubyamf/rails_installer_files/rubyamf_controller.rb","./app/controllers/rubyamf_controller.rb",false)
  FileUtils.copy_file("./vendor/plugins/rubyamf/rails_installer_files/rubyamf_helper.rb","./app/helpers/rubyamf_helper.rb",false)
  FileUtils.copy_file("./vendor/plugins/rubyamf/rails_installer_files/crossdomain.xml","./public/crossdomain.xml", false)
  
  mime = true
  mime_types_file_exists = File.exists?('./config/initializers/mime_types.rb')
  mime_config_file = mime_types_file_exists ? './config/initializers/mime_types.rb' : './config/environment.rb'
  
  File.open(mime_config_file, "r") do |f|
    while line = f.gets
      if line.match(/application\/x-amf/)
        mime = false
        break
      end
    end
  end
  
  if mime
    File.open(mime_config_file,"a") do |f|
      f.puts "\nMime::Type.register \"application/x-amf\", :amf"
    end
  end
  
  route_amf_controller = true
  File.open('./config/routes.rb', 'r') do |f|
    while  line = f.gets
      if line.match("map.rubyamf_gateway 'rubyamf_gateway', :controller => 'rubyamf', :action => 'gateway")
        route_amf_controller = false
        break
      end
    end
  end

  if route_amf_controller
    routes = File.read('./config/routes.rb')
    updated_routes = routes.gsub(/(ActionController::Routing::Routes.draw do \|map\|)/) do |s|
      "#{$1}\n  map.rubyamf_gateway 'rubyamf_gateway', :controller => 'rubyamf', :action => 'gateway'\n"
    end
    File.open('./config/routes.rb', 'w') do |file|
      file.write updated_routes
    end
  end
  
rescue Exception => e
  puts "ERROR INSTALLING RUBYAMF: " + e.message
end