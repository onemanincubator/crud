module Crud

	module Config
    
  	module HelperMethods
    	
  		# called by control_panel_index
  		def config_cp_intro
  			"The #{request.domain} data is accessed and/or modified
				by different types of users (including admins) in various
				locations of the site. #{link_to_action 'Config'} enables 
				admins to configure how the data is presented in these locations."
			end
  	
			#
			# index action
			#
		
  		def config_cp_index(params = {})
  	  	row_tags = ""
  			%w(select_fields_for_forms).each do |method|
  				row_tags << content_tag(:tr, content_tag(:td, 
  					link_to(method.titleize, :action => 'config', 
  								:m => method)))
  			end
  			intro = content_tag(:p, "Config allows you to set how the 
  			#{request.domain} data is presented to users througout the 
  			site. Listed below are the different ways in which to set 
  			the configurations.")
  			intro + content_tag(:table, row_tags)
  		end
  	
  		def select_fields_for_forms(params = {})
  			# 1. new link
  			new_link = content_tag(:p, 
  				link_to("Add a new config", :action => 'new', 
  																		:table => 'crud_configs'))

  			# 2. selector
  			data = {
  			'models' => (Crud.tables_list.map {|t| t.classify}),
  			'controllers' => Crud.app_controllers_list,
  			'actions' => %w(list show new edit read write root)
  			}
  			rows_html = ""
  			# heading
  			cells_html = content_tag(:th, 'Table')
  			cells_html << content_tag(:th, 'Controller')
  			cells_html << content_tag(:th, 'Action')
  			rows_html << content_tag(:tr, cells_html)
  			# selectors
  			cells_html = ""
  			%w(models controllers actions).each do |key|
  				list = SimpleListList.find_or_create("crud_#{key}")
  				cells_html << content_tag(:td, 
  					select_tag("#{key.singularize}_name_id",
  						options_for_select(data[key].map {|e|
  							[e.titleize, 
  								list.find_or_create_item(e).id]})))
  			end
				cells_html << content_tag(:td, 
					submit_to_remote('load', 'Load', 
						:url => {:action => 'show_config'}))
				rows_html << content_tag(:tr, cells_html)
				selector = content_tag(:form, 
					#hidden_field_tag('m', 'select_fields_for_forms') + # parameter
					content_tag(:table, rows_html, :cellspacing => '5'), # selector
					:action => url_for(:action => 'show_config'))
					 
  			# 3. config show/edit  			
  			configs = content_tag(:div, 
  									"[Click 'Load' to view/edit the config]",
  									:id => 'config_attributes_wrapper')
  			
 				new_link + selector + configs
  		end
  		
  		def show_config
  			return "@crud_config variable missing" unless 
  				@crud_config.is_a?(CrudConfig)
  			html = link_to_remote("Edit Fields List", 
  				:url => {:action => 'edit_config'
  								}.merge(config_params))
				if @crud_config.new_record?
    			rows_html = content_tag(:tr, content_tag(:td, 
    				"(No configuration has been explicitly set for this context. 
    				Below are the table fields as they appear in the database.)"))
    			if (model = @crud_config.model)
    				rows_html << model.column_names.map {|column_name|
    					content_tag(:tr, 
    						content_tag(:td, column_name.titleize))}.join(' ')
    			else
    				rows_html << content_tag(:tr, content_tag(:td,
    					"#{@crud_config.model_name_id.to_s} is not a valid 
    					model name id"))
    			end
    			html << content_tag(:table, rows_html, :cellspacing => '5')
    		else
					html << manage_list(@crud_config, 'crud_attributes')
    		end
    		html
  		end
  	
  		def edit_config
  			# attributes arrays
  			unless @crud_config.new_record? # existing config
  				existing_attributes = @crud_config.crud_attribute_names
      		all_attributes = 
      			Crud.crud_model_attribute_names(@crud_config.model.name)
     		else # new config
     			existing_attributes = []
     			all_attributes = @crud_config.model.column_names
     		end
     		
     		# hidden fields re this crud_config record
     		prms = config_params
     		prms.delete(:id)
     		hidden_html = prms.map {|key, value|
     			hidden_field_tag("crud_config[#{key.to_s}]", value)}.join(' ')
     		
     		# attributes html
      	rows_html = ""
    		# db attributes
    		all_attributes.each do |attribute|
    			rows_html << form_row(
    				check_box_tag("crud_attribute_names[]", attribute, 
    								existing_attributes.include?(attribute)),
    				attribute.humanize)
    		end
    		# non-db attributes
    		rows_html << form_row("Other<br>(delimit with commas)",
    			text_area_tag("crud_config[extra_fields]",
    					(existing_attributes-all_attributes).map {
    					|r| r.humanize}.join(', ')))
    		html = content_tag(:table, rows_html)
    		
    		# buttons
        buttons_html = submit_to_remote('cancel', 'Cancel', 
          :url => {:action => 'show_config'}.merge(config_params))
        buttons_html << "&nbsp;&nbsp;"
        buttons_html << submit_to_remote('save', 'Save', 
          :url => {:action => 'save_config', :id => @crud_config})

				content_tag(:form, hidden_html + html + buttons_html, 
										:class => "form_crud")    	
  		end
  		
  		private
  		
  		# generates a single row of an input form table
    	def form_row(label,field)
      	content_tag(:tr, content_tag(:th, label) + content_tag(:td, field))
    	end
    	
    	def config_params
  			{	:id => @crud_config,
  				:model_name_id => @crud_config.model_name_id,
  				:controller_name_id => @crud_config.controller_name_id,
  				:action_name_id => @crud_config.action_name_id }
  		end

  	  	
		end
  	
	end
  
end
