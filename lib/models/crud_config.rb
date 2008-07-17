class CrudConfig < ActiveRecord::Base
  has_many :crud_attributes, :order => :position, :dependent => :destroy
  acts_as_simple_list 	:model_name,			:list => 'crud_models'
  acts_as_simple_list 	:controller_name,	:list => 'crud_controllers'
  acts_as_simple_list 	:action_name,			:list => 'crud_actions'
  
  validates_uniqueness_of :model_name_id, 
  												:scope => [:controller_name_id, :action_name_id]
  
  attr_accessor :old_attributes, :new_attributes
  after_save :delete_removed_attributes
  
  class << self
  
  	def find_or_create(model_name_id, controller_name_id, action_name_id)
	  	self.find_or_create_by_model_name_id_and_controller_name_id_and_action_name_id(
	  		model_name_id, controller_name_id, action_name_id)
	  end
  
 		def find_only(model_name_id, controller_name_id, action_name_id)
  		self.find_by_model_name_id_and_controller_name_id_and_action_name_id(
  			model_name_id, controller_name_id, action_name_id)
  	end
  	
  	def find_simple_list_item(name, attribute)
  		return if name.blank?
  		return unless %w(model_name_id controller_name_id 
  											action_name_id).include?(attribute)
  		SimpleListList.find_or_create(
  			"crud_#{attribute.gsub(/_name_id/, 's')}"
  			).find_or_create_item(name)
  	end
	
	end
  
  def name
  	attrs = %w(model_name_id controller_name_id action_name_id).map {|attr|
  		SimpleListItem.find(self.send(attr)).name unless 
  			self.send(attr).blank? rescue nil}.compact
  	attrs.blank? ? self.id.to_s : attrs.join('-')
  end
  
  def model
  	self.model_name.name.constantize rescue nil
  end
  
  def controller
  	return unless self.controller_name
  	self.controller_name.name.constantize
  end
  
  def crud_attribute_names
  	self.crud_attributes.map {|r| 
  		SimpleListItem.find(r.attribute_name_id).name}
  end
  
  def crud_attributes_hash
  	hash = Hash[*self.crud_attributes.map {|r| 
  		[SimpleListItem.find(r.attribute_name_id).name, 
  			r]}.flatten]
  	hash.merge({'_attributes' => crud_attribute_names})
  end 	
  
  def crud_attribute_names=(attributes)
  	return unless attributes.is_a? Array
  	return if attributes.blank?
  	write_crud_attributes(attributes)
  end
  
  def extra_fields=(attributes_string)
  	return unless attributes_string.is_a? String
  	return if attributes_string.blank?
  	attributes = attributes_string.split(/\s*[,;]\s*/).map {|s| s.underscore}
  	# TODO: raise an invalid exception if respond_to? fails
  	object = self.model.new
  	attributes = attributes.map {|a| a if object.respond_to?(a)}.compact
  	return if attributes.blank?
  	write_crud_attributes(attributes)
  end
  
  def delete_removed_attributes
  	return unless @old_attributes
  	return if @old_attributes.blank?
  	attributes_hash = self.crud_attributes_hash
  	(@old_attributes - @new_attributes).each do |attribute|
  		attributes_hash[attribute].destroy
  	end
  end

  def write_crud_attributes(attributes)
  	# set up old and new attributes for delete_removed_attributes
  	@old_attributes ||= self.crud_attribute_names
  	@new_attributes ||= []
  	@new_attributes += attributes
  	# save (or find) the new attributes
  	list = SimpleListList.find_or_create("crud_#{self.model.name.tableize}")
  	attributes.each do |attribute|
  		CrudAttribute.find_or_create(list.find_or_create_item(attribute).id, self.id)
  	end
  end
  
end
