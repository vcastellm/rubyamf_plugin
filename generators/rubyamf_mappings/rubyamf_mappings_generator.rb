require 'rbconfig'

class RubyamfMappingsGenerator < Rails::Generator::Base
  
  MODEL_DIR = File.join(Rails::VERSION::MAJOR < 3 ? RAILS_ROOT : ::Rails.root.to_s, "app/models") #fosrias: RAILS_ROOT deprectated in Rails 3
  
  def initialize(runtime_args, runtime_options = {})
  end

  def manifest
    record do |m|
      mappings = map_models_with_all_attributes_and_associations
      puts 'Copy this block of text into config/rubyamf_config.rb:'
      puts mappings
    end
  end

 private

  def create_full_map(klass)
    mapping = <<-MAPPING

    ClassMappings.register(
      :actionscript  => '#{klass.class_name}',
      :ruby          => '#{klass.class_name}',
      :type          => 'active_record'
    MAPPING

    if associations = associations_for(klass)
      mapping.chop! << ",\n"
      mapping <<  <<-ASSOC
      :associations  => #{associations}
      ASSOC
    end

    if attributes = attributes_for(klass)
      mapping.chop! << ",\n"
      mapping <<  <<-ASSOC
      :attributes    => #{attributes}
      ASSOC
    end

    mapping.chop! << ")\n"
  end

  def create_simple_map(klass)
    "    ClassMappings.register(:actionscript => '#{klass.class_name}', :ruby => '#{klass.class_name}', :type => 'active_record')\n"
  end

  def associations_for(klass)
    klass.reflections.keys.empty? ? nil : klass.reflections.stringify_keys.keys.inspect
  end

  def attributes_for(klass)
    klass.column_names.empty? ? nil : klass.column_names.inspect
  end

  def get_model_names
    models = []
    Dir.chdir(MODEL_DIR) do 
        models = Dir["**/*.rb"]
    end
    models
  end

  def map_models(full=false)
    mappings = ''
    get_model_names.each do |m|
      class_name = m.sub(/\.rb$/,'').camelize
      begin
        klass = class_name.split('::').inject(Object){ |klass,part| klass.const_get(part) }
        if klass < ActiveRecord::Base && !klass.abstract_class?
          mappings << (full ? create_full_map(klass) : create_simple_map(klass))
        else
          puts "Skipping #{class_name}: either not active record or abstract"
        end
      rescue Exception => e
        puts "Unable to map #{class_name}: #{e.message}"
      end
    end
    mappings
  end

  def map_models_with_all_attributes_and_associations
    map_models(true)
  end

end