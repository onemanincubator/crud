module Crud
  
  class << self
    
    # return a select array for a :belongs_to association via attribute_name
    def choices_for_model_select(model_name, attribute_name, options ={})
      table_name, method = associated_search_data(model_name, attribute_name)
      method ||= "id" if options[:id_ok]
      return unless table_name && method # can't find necessary search data
      return if (records = table_name.classify.constantize.find(:all)).blank? # no records
      records.collect {|r| [r.send(method).to_s, r.id]}
    end
    
    # return the name of the :belongs_to parent object of content via attribute_name
    def name_of_parent(content,attribute_name)
      return if content.send(attribute_name).blank? # blank attribute
      return unless (assoc = get_association(content.class.name,attribute_name)) # no association
      return unless (object = content.send(assoc.name)) # no parent object
      return unless (name_method = get_name_method(object.class.name)) # parent has no name method
      object.send(name_method).to_s
    end
    
    # return the :belongs_to association object for the attribute if one exists   
    def get_association(model_name, attribute_name)
      return if association_is_polymorphic?(model_name, attribute_name)
      model_name.constantize.reflect_on_all_associations(:belongs_to).map {|a|
                a if a.primary_key_name.to_sym == attribute_name.to_sym}.compact.first
    end 
    
    # for model_name, return names of all possible db-derived attributes
    # supported by crud
    def crud_model_attribute_names(model_name)
    	# build hash of has_many associations
    	hm_reflections = Hash[*model_name.constantize.reflect_on_all_associations(
    		:has_many).map {|r| [r.name, r]}.flatten]
    	# collect list of app-defined models
    	Dir.chdir("#{RAILS_ROOT}/app/models")
			app_tables = Dir['*.rb'].map {|fn| fn.gsub(/\.rb/, "").tableize}
			# pare down the list of has_many associations
    	hm_names = []
    	hm_reflections.each do |name, reflection|
    		next if reflection.source_reflection # has_many :through not supported
    		next unless app_tables.include?(reflection.table_name) # use only app associations
    		hm_names << name.to_s
    	end
    	# return table attributes plus has_many attributes
    	model_name.constantize.column_names + hm_names
    end    

    ### Config Methods
    
    # return a hash of 'attribute_name => attribute_options' pairs for model_name
    # hash also includes an '_attribute' key to preserve atribute order
    def get_columns_hash(model_name, controller_name, action_name)
      return unless model_name && controller_name && action_name

      # extract attributes array from db
      config = read_config(model_name, controller_name, action_name)
      attributes_hash = config.crud_attributes_hash if config
      
      @columns_hash = model_name.constantize.columns_hash
      
      if attributes_hash
				attributes = attributes_hash['_attributes']
      	a = attributes.map {|attribute| [attribute, 
      			{'type' => column_type(model_name, attribute)}.merge!(
      			attributes_hash[attribute].options_hash || {})]} # specific options for this attribute (if any)
			else
      	# use db columns as default if attribute extraction failed
      	attributes = model_name.constantize.column_names
      	a = attributes.map {|attribute| [attribute, 
      		Hash[*['type', column_type(model_name, attribute)].flatten]]}
      end
      
      # add in the '_attributes' key
      hash = Hash[*a.flatten].merge('_attributes' => attributes)
      
      # separate out the 'has_many' columns
      hash['_hm_attributes'] = hash['_attributes'].map {
      	|attribute| attribute if 
      	hash[attribute]['type'] == "has_many"}.compact
      hash['_attributes'] -= hash['_hm_attributes']
      
      hash
    end
    
    def convert_yml
    	crud_models = SimpleListList.find_or_create('crud_models')
    	crud_controllers = SimpleListList.find_or_create('crud_controllers')
    	crud_actions = SimpleListList.find_or_create('crud_actions')
    	
    	load_config_hash.each do |model_name, controller_names|
    		model_name_id = crud_models.find_or_create_item(model_name).id
    		controller_names.each do |controller_name, action_names|
    			controller_name_id = %w(generate default download chart).include?(controller_name) ?
    				nil : crud_controllers.find_or_create_item(controller_name).id
    			action_names.each do |action_name, attribute_names|
    				break if /default/ =~ action_name && !(%w(chart generate).include?(controller_name))
    				case controller_name
    				when 'download', 'chart'
    					action_name_id = crud_actions.find_or_create_item(controller_name).id
	   				when 'default'
    					break
	   				when 'generate'
	   					break unless action_name == 'default'
	   					action_name_id = crud_actions.find_or_create_item(controller_name).id
    				else
    					action_name_id = crud_actions.find_or_create_item(action_name).id
     				end
    				break unless 	(attribute_names.is_a? Hash) &&
    											(attribute_names['attributes'].is_a? Array)
   					config_id = CrudConfig.find_or_create(
    						model_name_id, controller_name_id, action_name_id).id
    				attribute_names['attributes'].each do |attribute_name|
    					attribute_name_id = SimpleListList.find_or_create(
    						"crud_#{model_name.tableize}").find_or_create_item(attribute_name).id
    					CrudAttribute.find_or_create(attribute_name_id, config_id)
    				end
    			end    			
    		end
    	end
    end
    
    #
    # return the appropriate config record (if any) for
    # model_name, controller_name,  and action_name.
    # Goes through a prioritization hierarchy to selector
    # the applicable config.
    #
    def read_config(model_name, controller_name, action_name)
      model_name_id = SimpleListList.find_or_create(
      	'crud_models').find_or_create_item(model_name).id
      controller_name_id = SimpleListList.find_or_create(
      	'crud_controllers').find_or_create_item(controller_name).id
      action_name_id = SimpleListList.find_or_create(
      	'crud_actions').find_or_create_item(action_name).id
      config = 
      	CrudConfig.find_only(model_name_id, controller_name_id, action_name_id)
      return config if config
      generic_name_id = %w(new edit generate).include?(action_name) ?
      	SimpleListList.find_or_create('crud_actions').find_or_create_item('write').id :
      	SimpleListList.find_or_create('crud_actions').find_or_create_item('read').id
      config = 
      	CrudConfig.find_only(model_name_id, controller_name_id, generic_name_id)
      return config if config
      root_name_id = SimpleListList.find_or_create('crud_actions').find_or_create_item('root').id
      config = 
      	CrudConfig.find_only(model_name_id, controller_name_id, root_name_id)
      return config if config
      config = CrudConfig.find_only(model_name_id, nil, action_name_id)
      return config if config
			config = CrudConfig.find_only(model_name_id, nil, generic_name_id)
      return config if config
      config = CrudConfig.find_only(model_name_id, nil, root_name_id)
      return config
    end
        
    private

    # crud recognizes a number of column types in addition to the default rails ones
    def column_type(model_name, attribute, options = {})
    	
    	# invalid attribute
    	return 'invalid' unless model_name.constantize.new.respond_to?(attribute)
    	
      # price, percentage (specified in the config field)
      return options['type'] if options && %w(price percentage).include?(options['type'])
      
      # all other types must be derived and confirmed
      if /_id\z/ =~ attribute
        
        # simple_list
        if model_name.constantize.respond_to?('is_it_a_simple_list?') && 
              model_name.constantize.is_it_a_simple_list?(attribute) 
          return "simple_list"
          
        # multi_simple_list
        elsif model_name.constantize.respond_to?('is_it_a_multi_simple_list?') && 
              model_name.constantize.is_it_a_multi_simple_list?(attribute) 
          return "multi_simple_list"
      
        # :belongs_to
        elsif Crud.get_association(model_name, attribute) 
          return "belongs_to"
          
        end
        
      # multi_simple_list list
      elsif (/_list\z/ =~ attribute) &&
            model_name.constantize.respond_to?('is_it_a_multi_simple_list?') &&
            model_name.constantize.is_it_a_multi_simple_list?(attribute)
        return "multi_simple_list"
      
      # :has_many sub_form
      elsif model_name.constantize.respond_to?('is_it_a_sub_form?') && 
            model_name.constantize.is_it_a_sub_form?(attribute)
        @exists_has_many = true
        return "has_many"
      
      # see recognized_rails_types  
      elsif (column = @columns_hash["#{attribute}"])
        return column.type.to_s if 
        recognized_rails_types.include? column.type.to_s 
        
      end
      
      # string = crud default
      "string" 
    end
    
    def recognized_rails_types
    	%w(string text boolean date integer decimal)
    end  
    
    # checks config/crudable_view.yml if attribute_name is declared a price field
    def is_this_a_price?(model_name,attribute_name)
      return unless @config_hash ||= load_config_hash # no config file
      return unless @config_hash[model_name] # model missing
      return unless @config_hash[model_name]['price'] # price fields missing
      return [@config_hash[model_name]['price']].flatten.include?(attribute_name)
    end 
        
    # return associated object & method for searching
    def associated_search_data(model_name,attribute_name)
      return if association_is_polymorphic?(model_name,attribute_name) # polymorphic association
      return unless (assoc = get_association(model_name,attribute_name)) # no association
      return assoc.table_name.singularize, get_name_method(assoc.table_name)
    end
    
    def association_is_polymorphic?(model_name,attribute_name)
    	if /_id\z/ =~ attribute_name
      	model_name.constantize.column_names.include?(
                "#{/_id\z/.match(attribute_name).pre_match}_type")
      else
      	return false unless (assoc =
      		model_name.constantize.reflect_on_association(attribute_name.to_sym))
      	assoc.table_name rescue return true # polymorphics breaks here
      	return false
      end
    end
    
    # return the name of the column that is searched for and displayed in select lists
    def get_name_method(table_name)
      object = table_name.classify.constantize.new
      return 'name' if object.respond_to?('name')
      return 'id' if object.respond_to?('id')
    end
    
    def load_config_hash
      config_dir = File.join(File.expand_path(RAILS_ROOT),'config')
      return unless File.exist?(File.join(config_dir,'crudable_view.yml'))
      YAML.load_file(File.join(config_dir,"crudable_view.yml"))
    end  
    
  end
  
end
