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
  File.open("./config/environment.rb","r") do |f|
    while line = f.gets
      if line.match(/application\/x-amf/)
        mime = false
      end
    end
  end
  
  if mime
    File.open("./config/environment.rb","a") do |f|
      f.puts "\nMime::Type.register \"application/x-amf\", :amf"
    end
  end
rescue Exception => e
  puts "ERROR INSTALLING RUBYAMF: " + e.message
end