class CrudAttribute < ActiveRecord::Base
  belongs_to :crud_config
  acts_as_list :scope => :crud_config_id  
  acts_as_simple_list :attribute_name

  validates_uniqueness_of :attribute_name_id, :scope => :crud_config_id  
  
  def self.find_or_create(attribute_name_id, config_id)
  	self.find_or_create_by_attribute_name_id_and_crud_config_id(
  		attribute_name_id, config_id)
  end
  
  def name
  	self.attribute_name.name
  end
  
  def options_str
  	self.attribute_name.description.to_s
  end
  
  def options_hash
  	return if (options_str = self.options_str).blank?
  	Hash[*options_str.split(/\s*,\s*/).map {
  		|str| str.split(/\s*=>\s*/) if /=>/ =~ str}.compact.map {
  		|arr| [arr.first.to_sym, arr.last.to_i > 0 ?
  					arr.last.to_i : arr.last]}.flatten]
  end

end

