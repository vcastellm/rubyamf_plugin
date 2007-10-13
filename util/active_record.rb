class ActiveRecord::Base
  
  #member names to ignore on incoming VOs
  def self.magic_fields
    ['created_at','created_on','updated_at','updated_on']
  end
  
  #This holds the original incoming Value Object from deserialization time, as when an incoming VO with an 'id' property
  #on it is found, it is 'found' (Model.find(id)) in the DB (instead of Model.new(hash)). So right before the params hash
  #is updated for the rails request, I slip in this original object so you can do an "update_attributes(params[:model])"
  #and the correct 'update' values will be used.
  attr_accessor :original_vo_from_deserialization
  
  def as_single!
    SDTOUT.puts "ActiveRecord::Base#as_single! is no longer needed, all single active records return as an object. This warning will be taken out in 1.4, please update your controller"
    self
  end
  def single!
    SDTOUT.puts "ActiveRecord::Base#as_single! is no longer needed, all single active records return as an object. This warning will be taken out in 1.4, please update your controller"
    self
  end
  
  #get any associated data on an AR instance. I don't use AR reflection here
  #because it causes problems when recursing in the active_record_adapter.
  def get_associates
    keys = ['==','===','[]','[]=','abstract_class?','attr_accessible',
    'attr_protected','attribute_names','attribute_present?','attributes',
    'attributes=','attributes_before_type_cast','base_class','benchmark',
    'class_of_active_record_descendant','clear_active_connections!',
    'clear_reloadable_connections!','clone','column_for_attribute',
    'column_names','columns','columns_hash','compute_type','connected?',
    'connection','connection','connection=','content_columns',
    'count_by_sql','create','decrement','decrement!','decrement_counter',
    'delete','delete_all','destroy','destroy','destroy_all','eql?',
    'establish_connection','exists?','find','find_by_sql','freeze','frozen?',
    'errors','new_record_before_save','rubyamf_single_ar',
    'has_attribute?','hash','id','id=','increment','increment!',
    'increment_counter','inheritance_column','new','new_record?','new_record','primary_key',
    'readonly?','reload','remove_connection','require_mysql',
    'reset_column_information','respond_to?','sanitize_sql','sanitize_sql_array',
    'sanitize_sql_hash','save','save!','serialize','serialized_attributes',
    'set_inheritance_column','set_primary_key','set_sequence_name',
    'set_table_name','silence','table_exists?','table_name','to_param',
    'toggle','toggle!','update','update_all','update_attribute',
    'update_attributes','update_attributes!','with_exclusive_scope','with_scope']
    finals = []
    possibles = self.instance_variables.clone
    possibles.each do |k|
      if keys.include?(k[1,k.length])
        next
      end
      finals << k if k != '@attributes'
    end
    finals
  end

  #get column_names for an active_record
  def get_column_names
    return self.attributes.map{|k,v| k}
  end
  
  #turn this ActiveRecord into an update hash
  def to_hash
    o = {}
    column_names = self.get_column_names
    
    #first write the primary "attributes" on this AR object
    column_names.each do |k|
      val = self.send(:"#{k}")
      o[k] = val
    end
    
    associations = self.get_associates
    if !associations.empty? && associations != nil
      #now write the associated models with this AR
      associations.each do |associate|
        na = associate[1, associate.length]
        ar = self.send(:"#{na}")
        o[na] = ar
      end
    end
    o
  end
  
  #This takes an update hash used in instantiating new ActiveRecord instances,
  #and updates any members that are considered associations but didn't
  #have any values sent with it (nil)
  def self.update_nil_associations(klass, hash, orig_vo_openstruct, isnew)
    os = orig_vo_openstruct
    associations = klass.reflect_on_all_associations
    if !associations.empty? && !associations.nil?
      associations.each do |ass|
        n = ass.name.to_s
        if ass.macro == :belongs_to
          if hash[n].nil? || hash[n].to_s == 'NaN' || hash[n].to_s == 'undefined'
            os.delete_field(n.to_sym)
            hash.delete(n.to_s)
          end
        
        elsif ass.macro == :has_many || :has_and_belongs_to_many
          if hash[n].nil? || hash[n].to_s == 'NaN' || hash[n].to_s == 'undefined'
            os.delete_field(n.to_sym)
            hash.delete(n.to_s)
          end
          
        elsif ass.macro == :through
          if hash[n].nil? || hash[n].to_s == 'NaN' || hash[n].to_s == 'undefined'
            os.delete_field(n.to_sym)
            hash.delete(n.to_s)
          end
        end
      end
    end
    hash
  end
  
  #get rid of NaN's in an incoming VO
  def self.update_nans(hash)
    hash.each do |k,v|
      if v.to_s == 'NaN'
        hash[k] = nil
        hash.delete(k.to_s)
      end
    end
    hash
  end
end