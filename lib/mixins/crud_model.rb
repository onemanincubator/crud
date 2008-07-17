module Crud
  
  module ModelMethods
        
    def self.included(base) #:nodoc:
      base.extend(ClassMethods)
    end

    module ClassMethods 
      
      def acts_as_crud(options={})
        
        cattr_accessor :sub_form_attributes
        self.sub_form_attributes = [options[:sub_forms_for]].flatten.compact.map {|attribute| 
                                    attribute.to_s} if options[:sub_forms_for]
        
        # define [attribute]_attributes methods
        [self.sub_form_attributes].flatten.compact.each do |attribute|
                    
          # *** SHOULD RAISE ERROR instead of just skipping
          # checking validity of sub_form attribute
          next unless (assoc = self.reflect_on_association(attribute.to_sym))          
          next unless assoc.macro == :has_many
                    
          attribute_name, table_name = 
            attribute.to_s.underscore.singularize, assoc.table_name.singularize
          
          after_validation  "validate_#{attribute_name.pluralize}"
          after_create      "create_#{attribute_name.pluralize}"   
          attr_accessor "#{attribute_name}_attributes"
          
          # validate_ builds objects from the attributes and checks their validity
          define_method("validate_#{attribute_name.pluralize}") do
            return unless (objects = self.send("#{attribute_name}_attributes")).is_a? Hash
            invalid = 0
            objects.each do |k,attributes|
              next if attributes.is_a? table_name.classify.constantize
              invalid += 1 if !(object = table_name.classify.constantize.new(attributes)).valid?
              objects[k] = object
            end
            # add an error to the parent to make sure it can't be saved
            self.errors.add("#{attribute_name.titleize.pluralize}", 
                            "(#{invalid} of them) have errors") if invalid > 0
          end
          
          # create_ saves the validated objects and joins them to self
          define_method("create_#{attribute_name.pluralize}") do
            return unless (objects = self.send("#{attribute_name}_attributes")).is_a? Hash
            self.send(attribute_name.pluralize).push(*objects.values)
          end
          
        end
        
        def self.is_it_a_sub_form?(attribute_name)
          return false unless self.sub_form_attributes
          return self.sub_form_attributes.include?(attribute_name.to_s)
        end        
        
        include Crud::ModelMethods::InstanceMethods
              
      end
    end

    module InstanceMethods
    
			# set posted_at to indicate this was posted
    	def post
    		return unless self.respond_to?('posted_at')
      	self.update_attribute(:posted_at, Time.now) 
      end
          
      def is_a_draft?
      	return false unless self.respond_to?('posted_at')
      	self.posted_at.nil?
      end
      
      def is_fresh?
      	self.created_at == self.updated_at
      end
      
    end
  end
end
