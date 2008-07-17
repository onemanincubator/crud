module Crud
  
  module HelperMethods
    
    #################################################################################
    #
    # Main CRUD methods: list, show, new, edit
    #
    #################################################################################

    def list(options = {})
      new_link = controller.class.read_only ? "" : add_a_new
      content_tag(:div, new_link +
                        content_tag(:div, @content_list.blank? ? 
                                          "there are no #{@table.titleize.pluralize}" : 
                                          list_items_tag, 
                                    :id => "#{@table.tableize}_list_wrapper"),
                  :id => "show_crud")
    end
    
    def show(options = {})
      new_link = controller.class.read_only ? "" : add_a_new
      content_tag(:div, return_to_list +  new_link + read(@content, 'show', options), 
                  :id => "show_crud")
    end
    
    def new(options = {})
      content_tag(:div, return_to_list + form_title(@content) + 
      									input_form(@content, 'new'), :id => "new_crud")
    end
    
    def edit(options = {})
      content_tag(:div, return_to_list + form_title(@content) +
      									input_form(@content, 'edit'), :id => "edit_crud")
    end
    
    def list_items_tag(options = {})
      #initialize
      columns_hash = 
        get_columns(@table.classify, controller.controller_class_name, 'list')
      columns = columns_hash['_attributes'] + columns_hash['_hm_attributes']
      has_many_columns = columns_hash['_hm_attributes']
      @db_columns_hash ||= @table.classify.constantize.columns_hash
      
      html = ""
            
      # column headings
      row_html = ""
    	columns.each do |attribute_name|
    	  attribute_options = columns_hash[attribute_name]
        if @db_columns_hash[attribute_name].nil?
          th_html = attribute_name.humanize
        else # ajax link
          params = self.params.to_hash.symbolize_keys
          th_html = link_to(attribute_name.humanize, 
                          params.rec_merge!(:order => attribute_name))
        end
        row_html << content_tag(:th, th_html)
      end
      html << content_tag(:tr, row_html)

      # rows
      first_attribute_name = columns.shift
      first_attribute_options = columns_hash[first_attribute_name]
      first_type = first_attribute_options['type']
      
      @content_list.each_with_index do |content,i| 
        unless controller.class.admin
          next if content.respond_to?('is_a_draft?') && content.is_a_draft?
        end                                    
    	  
    	  # first column
    	  output = send("#{first_type}_output".to_sym, content, first_attribute_name)
    	  row_html = content_tag(:td, link_to(output, :action => 'show', :id => content, 
    	                                              :table => @table))
    	  
    	  # remainder of columns
      	columns.each do |attribute_name| # columns have been shifted by here
      	  attribute_options = columns_hash[attribute_name]
          type = attribute_options['type']
          row_html << content_tag(:td, send("#{type}_output".to_sym, content, attribute_name))
    	  end
    	  
    	  # actions
    	  unless controller.class.read_only
      	  row_html << content_tag(:td, link_to('Open', :action => 'show', :id => content, 
      	                                              :table => @table))
    	    if has_many_columns.blank? # enable editing only within show page
        	  row_html << content_tag(:td, link_to('Edit', :action => 'edit', :id => content, 
        	                                              :table => @table))
      	  end 
      	  row_html << content_tag(:td, link_to('Delete', {:action => 'destroy', 
      	                            :id => content, :table => @table}, 
      	                            :confirm => 
                          "Are you sure you want to delete #{@table.titleize} #{content.id}?", 
      	                            :method => :delete))
      	end
    	  html << content_tag(:tr, row_html, :class => "list_row_#{i.modulo(2).to_s}_crud")
    	end
    	
    	list = content_tag(:table, html)
    	pagination_links = will_paginate(@content_list, :remote => true) if
    	                    self.respond_to?('will_paginate')
    	                    #self.params.
      content_tag(:div, pagination_links.to_s + list, :class => "list_items_crud")
    end
    
    #################################################################################
    #
    # Component CRUD methods: input_form, form, read, read_subform, 
    #                         and build_belongs_to_input
    #
    #   These are used by the main CRUD view methods, and also by ajax methods
    #
    #################################################################################

    def input_form(content, action_name, options = {})
      form_name = "#{action_name}#{content.class.name}Form"
    	action_name == 'new' ? 
      	(next_action, method = 'create', 'post') : # create
      	(next_action, method = 'update', 'put') # update
      table = content.class.name unless @no_param 
      action = url_for({:action => next_action, :id => content, 
                        :table => table}.merge(options))
      content_tag(:form,  hidden_field_tag('_method', method) + # re bug in content_tag
                          _form(content, action_name, options) + 
                          place_cursor(form_name), 
                  :action => action, 
                  :name => form_name, :id => form_name, :method => 'post')
    end
    
    def _form(content, action_name, options = {})
      # initialize
      model_name, object_name  = content.class.name, content.class.name.underscore
      instance_variable_set("@#{object_name}", content) # necessary for rails helper methods
    	columns_hash = 
    	    get_columns(model_name, controller.controller_class_name, action_name)
    	columns = columns_hash['_attributes']
    	has_many_columns = columns_hash['_hm_attributes']
    	
      html = error_messages_for(object_name)
      
      # treat editing crud_config records specially
      #return edit_crud_config(content, html) if 
      #	action_name == 'edit' && content.is_a?(CrudConfig)

      # 'Close' link
      html << (options[:no_buttons] ? content_tag(:span, link_to_remote("[Close]", 
      	          :url => {:action => "close_ajax", :wrapper => options[:wrapper]}),
                  :class => "actions_crud") : "")
      
    	# generate hidden id field unless columns already has one
    	#unless columns_hash['id']
      #  html << hidden_field(object_name, 'id', 
      #          :name => ("#{options[:name]}[id]" if options[:name]))
      #end 
      
    	# standard columns
      row_html = ""
      columns.each do |attribute_name|
    	  attribute_options = columns_hash[attribute_name]
        type = attribute_options['type']
        attribute_options.merge!(:name => 
            "#{options[:name]}[#{attribute_name}]") if options[:name]
      	row_html << form_row(attribute_name.humanize, send("#{type}_input".to_sym, 
      	                    object_name, attribute_name, attribute_options))
      end
      html << content_tag(:table, row_html)
      
      # record id of first input field for placing cursor there
      @first_field ||= get_first_field(object_name, columns, html)
      
      # has_many columns for a multi-model form
      has_many_columns.each do |attribute_name|
        # initalize
    	  attribute_options = columns_hash[attribute_name]
        name = "#{options[:name] || object_name}[#{attribute_name.singularize}_attributes]"
        wrapper = "#{get_unique_tag}_#{attribute_name}_wrapper"
        table_name = content.class.reflect_on_association(attribute_name.to_sym).table_name        

        # label
        html << content_tag(:b, attribute_name.humanize)
        
        # forms for :has_many objects
        forms_html = ""
        get_has_many_objects(content, attribute_name).each do |object|
          next unless object.is_a? table_name.classify.constantize
          forms_html << wrapped_form(object, action_name,
                              options.merge(:wrapper =>     wrapper,
                                            :name =>        "#{name}[#{get_unique_tag}]", 
                                            :no_buttons =>  true,
                                            :input_form =>  nil))
        end
        html << content_tag(:div, forms_html, :id => wrapper)
        
        # link for adding another has_many object
        html << content_tag(:div, link_to_new_remote(:attribute_name =>  attribute_name, 
                                  :context =>         'form_has_many', 
                                  :wrapper =>         wrapper, 
                                  :name =>            name, 
                                  :table =>           table_name),
                            :class => "actions_crud")
      end
      
      # buttons for form, unless turned off
      unless options[:no_buttons]
        html << buttons_for_crud(content, action_name, options)
      end
      
      content_tag(:div, html, :class => "form_crud")
    end

    def read(content, action_name, options = {})
      columns_hash = 
          get_columns(content.class.name, controller.controller_class_name, action_name)
    	columns = columns_hash['_attributes']
    	has_many_columns = columns_hash['_hm_attributes']      
      
      # main form
      html = content_tag(:div, read_subform(content, action_name, options),
                          :id => "#{get_wrapper_for(content)}")
                          
     	# has_many subforms
     	has_many_columns.each do |attribute_name|
       	# initialize
   	  	attribute_options = columns_hash[attribute_name]
       	wrapper = "#{attribute_name}_for_#{get_wrapper_for(content)}"
       	table_name = content.class.reflect_on_association(attribute_name.to_sym).table_name        
       
       	#label
       	html << content_tag(:b, attribute_name.humanize)
       
       	# subforms for the has_many objects
       	forms_html = ""
       	content.send(attribute_name).each do |object|
         	forms_html << read(object, action_name)
       	end
       	html << content_tag(:div, forms_html, :id => wrapper)
       
       	# link for adding subforms (will be rendered above within wrapper)
       	html << content_tag(:div, link_to_new_remote(:attribute_name =>  attribute_name, 
                                 :context =>         'read_has_many', 
                                 :wrapper =>         wrapper, 
                                 :name =>            nil, 
                                 :table =>           table_name,
                                 :parent_type =>     content.class.name, 
                                 :parent_id =>       content),
                           :class => "actions_crud")
     	end
      
      content_tag(:div, content_tag(:div, html, :class => "read_crud"), 
                  :id => "full_#{get_wrapper_for(content)}")  
    end
    
    def read_subform(content, action_name, options = {})
      # initialize
      columns_hash = 
          get_columns(content.class.name, controller.controller_class_name, action_name)
    	columns = columns_hash['_attributes']
    	has_many_columns = columns_hash['_hm_attributes']      
            
      # title/name
      html = content_tag(:span, name_of(content, :long => true), :class => "title_crud")
      
      # Edit | Delete links
      unless controller.class.read_only
    	  html << content_tag(:span, 
    	              link_to_remote("Edit", 
    	                        :url => {:action => 'edit', :id => content, 
    	                        :table => content.class.name, 
    	                        :wrapper => get_wrapper_for(content)},
    	                        :method => "get") +
    	              "&nbsp;|&nbsp;" +
    	              link_to_remote("Delete", 
    	                        :url => {:action => 'destroy', :id => content, 
                          	  :table => content.class.name, 
                          	  :wrapper => "full_#{get_wrapper_for(content)}"},
	                            :confirm => 
	          "Are you sure you want to delete #{name_of(content, :long => true)}?", 
                          	  :method => :delete),
    	              :class => "actions_crud")
    	end
    	
    	# treat crud_config records specially
    	# return show_crud_config(content, html) if content.is_a?(CrudConfig)
    	
    	# display fields
      rows_html = ""
      columns.each do |attribute_name|
    	 	attribute_options = columns_hash[attribute_name]
    	 	type = attribute_options['type']
      	rows_html << form_row(attribute_name.humanize, send("#{type}_output".to_sym, 
      	                                                content, attribute_name))
      end
      html << content_tag(:table, rows_html)
      
      content_tag(:div, html, :class => "read_subform_crud")
    end
    
    #
    # manage_list -- manager for an acts_as_list list
    #
    
    def manage_list(content, items_method, options = {})
    	return "invalid parameters" if 
    		content.blank? || !content.respond_to?(items_method)
    	wrapper = "list_for_#{get_wrapper_for(content)}"
      common_params = {:action => 'manage_list_ajax', 
      	:content_type => content.class.name, :content_id => content.id, 
      	:items_method => items_method, :wrapper => wrapper}
      rows_html = ""
      content.send(items_method).each_with_index do |item, i|
      	cells_html = content_tag(:td,
      		link_to_remote("up",:url => {:ajax_action => 'move_up', 
      									:item_id => item.id}.merge(common_params)))
      	cells_html << content_tag(:td,
      		link_to_remote("down",:url => {:ajax_action => 'move_down', 
      									:item_id => item.id}.merge(common_params)))
      	cells_html << content_tag(:td, name_of(item))
   			rows_html << content_tag(:tr, cells_html,
   									:class => "list_row_#{i.modulo(2).to_s}_crud")
   		end
   		table = content_tag(:table, rows_html, :cellspacing => '5')
   		
   		content_tag(:div, content_tag(:h3, name_of(content)) + table,
   								:id => wrapper, :class => "list_items_crud")
    end
    
    def build_belongs_to_input(object_name, attribute_name, options = {})
      # build the drop-down
      items = Crud.choices_for_model_select(object_name.classify, 
                                                attribute_name, :id_ok => true)
      
      # ensure instance variable is set properly for select                                     
      unless (content = instance_variable_get("@#{object_name}"))
        content = options[:object_id] ?
            object_name.classify.constantize.find(options[:object_id]) :
            object_name.classify.constantize.new
        instance_variable_set("@#{object_name}", content)
        content.send("#{attribute_name}=", options[:belongs_to_id]) # newly created object
      end
      
      # generate drop-down
      html = items.blank? ?
            "list is empty" :
            fix_name(select(object_name, attribute_name, items, :include_blank => true),
                        object_name, attribute_name, options)
      
      # link for adding a new {table_name}
      table_name = Crud.get_association(object_name.classify, attribute_name).table_name        
      html << content_tag(:div, link_to_new_remote(:attribute_name =>  attribute_name, 
                                :context =>         'belongs_to', 
                                :wrapper =>         options[:wrapper], 
                                :name =>            options[:name], 
                                :table =>           table_name,
                                :object_name =>     object_name,
                                :object_id =>       content.id),
                          :class => "actions_crud")
    end
    
    def build_multi_simple_list_input(object_name, attribute_name, options = {})
      # ensure instance variable is set properly for select                                     
      unless (object = instance_variable_get("@#{object_name}"))
        object = options[:object_id] ?
            object_name.classify.constantize.find(options[:object_id]) :
            object_name.classify.constantize.new
        instance_variable_set("@#{object_name}", object)
      end
      
      # generate check boxes
      html = multi_select_id_field(object_name, attribute_name, options)
      
      # link for adding a new list_item
      html << content_tag(:div, link_to_new_remote(:attribute_name =>  attribute_name, 
                                :context =>         'multi_simple_list', 
                                :wrapper =>         options[:wrapper], 
                                :name =>            options[:name], 
                                :table =>           'simple_list_items',
                                :object_name =>     object_name,
                                :object_id =>       object.id),
                          :class => "actions_crud")      
    end
      
    #################################################################################
    #
    # Form Buttons:
    #
    #   These are used by the CRUD forms
    #
    #################################################################################

    # generates buttons for input_forms
    def buttons_for_crud(content, action_name, options = {})
      html = ""
      action_name == 'new' ?  next_action = 'create' : next_action = 'update'
      if options[:wrapper].nil? # this a non-ajax form
    		return buttons_for_crud_drafts(content) if controller.drafts || options[:drafts]
        html << submit_tag(next_action.titleize, :onclick => "Form.getInputs(this.form, 
                                    'submit').each(function(x) { if (x.value != 
                                    this.value) x.name += '_'; }.bind(this))")
        html << "&nbsp;&nbsp;"
        html << submit_tag("Cancel", :onclick => "Form.getInputs(this.form, 
                                    'submit').each(function(x) { if (x.value != 
                                    this.value) x.name += '_'; }.bind(this))")
      
      else # this is an ajax subform
        html << submit_to_remote(next_action, next_action.titleize, 
                    :url => {:action => "#{next_action}_ajax", :id => content}.merge(options))
        html << "&nbsp;&nbsp;"
        html << submit_to_remote('cancel', 'Cancel', 
                    :url => {:action => 'cancel', :id => content}.merge(options))
      end
      content_tag(:div, html, :class => "buttons_crud")
    end
    
    def buttons_for_crud_drafts(content)
    	html = ""
    	methods = ["Cancel", "Save and Preview", "Save"]
    	methods.push("Post") if content.respond_to?('is_a_draft?') &&
    														content.is_a_draft?
    	methods.each do |method|
      	html << "&nbsp;&nbsp;"
      	html << submit_tag(method, :onclick => "Form.getInputs(this.form, 
                                    'submit').each(function(x) { if (x.value != 
                                    this.value) x.name += '_'; }.bind(this))")
      end
      html
    end
            
    private    
    
    #################################################################################
    #
    # Form Helpers (private)
    #
    #   These are used by the component CRUD methods for building forms.
    #
    #################################################################################
    
    # links at the top of the main list, show, edit, and new pages
    def return_to_list
      content_tag(:p, link_to("Return to the #{@table.titleize} list", 
                      :action => 'list', :table => @table))
    end
    
    def add_a_new
      content_tag(:p, link_to("Add a new #{@table.titleize}", 
                              :action => 'new', :table => @table))
    end 
    
    def form_title(content)
      content_tag(:span, content.new_record? ? 
      	"New #{content.class.name.titleize}" : 
        "Edit #{name_of(content, :long => true)}",
        :class => "title_crud")
    end
           
    # generates link_to_remote command for ajax calls to 'new'
    def link_to_new_remote(options = {})
      if (missing_options = %w(attribute_name context wrapper name table) - 
                            options.stringify_keys.keys).empty?
        link_to_remote("Add a new #{options[:attribute_name].humanize.singularize}", 
                        :url => {:action => 'new'}.merge(options))
      else
        "link_to_new_remote error: missing options: #{missing_options.join(' ')}."
      end
    end
    
    # returns the name of content; returns id if no name
    def name_of(content, options = {})
      return "" unless content
      return content.name if content.respond_to?('name')
      return content.class.name.titleize unless content.respond_to?('id') 
      id = content.id.to_s
      options[:long] ? "#{content.class.name.titleize} ##{id}" : "##{id}"
    end
    
    # generates a single row of an input form table
    def form_row(label,field)
      content_tag(:tr, content_tag(:th, label) + content_tag(:td, field))
    end
    
    # checks whether columns contains field
    def columns_includes?(field, columns)
      Hash[*(columns.flatten)].keys.include?(field) 
    end
    
    # pulls the attribute name and options hash out of a column array
    def extract_from(column)
      return column.first, Hash.new.replace(column.last).symbolize_keys
    end
    
    # stores column arrays in instance variables
    def get_columns(model_name, controller_name, action_name)
    	if instance_variable_get("@#{model_name}_#{action_name}_columns").nil?
    	  instance_variable_set("@#{model_name}_#{action_name}_columns", 
    	  	Crud.get_columns_hash(model_name, 
    	  		controller.controller_class_name, action_name))
    	end
      return instance_variable_get("@#{model_name}_#{action_name}_columns")
	  end
    
    # pulls out the has_many columns from columns
    def extract_has_many_from(columns)
      columns.map {|column| column if column.last == "has_many"}.compact
    end
    
    # generate a div id string for an existing object that will be used by ajax methods
    def get_wrapper_for(object)
      "#{object.class.name.underscore}_#{object.id.to_s}_wrapper"
    end
    
    # wraps an input_form or form in a div id wrapper that is unique (in prep for ajax)
    def wrapped_form(object, action_name, options = {})
      form_wrapper = "#{get_unique_tag}_#{options[:wrapper]}"
      options.merge!(:wrapper => form_wrapper)
      content_tag(:div, options[:input_form] ?  
                        input_form(object, 'new', options) : _form(object, 'new', options),
                  :id => form_wrapper)
    end
        
    # generates an array of :has_many attribute_name objects for content
    def get_has_many_objects(content, attribute_name)
      objects_hash = content.send("#{attribute_name.singularize}_attributes")
      return objects_hash.values unless objects_hash.blank? # returning from error with subforms
      return [] unless content.errors.empty? # returning from error with no subforms
      return [content.class.reflect_on_association( # coming in from new -- generate one
              attribute_name.to_sym).table_name.classify.constantize.new] if content.new_record?
      content.send(attribute_name) # coming in from edit - return existing subforms
    end
    
    # scans html for the first field in an input form (in prep for place_cursor)
    def get_first_field(object_name, columns, html)
      return unless columns.first
      first_field = "id=\"#{object_name}_#{columns.first.first}"
      return unless (match = /#{first_field}.*?"/.match(html)) # scoop up chars that follow
      match[0][4,99].chop # lop off the leading id=" and trailing "
    end     
    
    # places the cursor in @first_field
    def place_cursor(form_name)
      content_tag(:script, "document.#{form_name}.#{@first_field}.focus();")
    end
    
    # generates html id from html name
    def idifize(name)
      return unless name.is_a? String
      name.gsub(/\]/) {|c| nil}.gsub(/\[/) {|c| "_"}
    end
    
    # generates a unique tag (used to keep ajax wrappers distinct)
    def get_unique_tag
      @prefixes ||= []
      prefix = 0
      loop do
        prefix = rand(1000)
        break unless @prefixes.include?(prefix)
      end
      @prefixes << prefix
      Time.now.to_i.to_s + @prefixes.last.to_s 
    end
    
    #################################################################################
    #
    # Field I/O (private)
    #
    #   These generate html for input fields, and output fields for the types
    #   recognized by crud, which include:
    #     string, text, boolean, date, belongs_to, simple_list, multi_simple_list,
    #     price, percentage, and has_many (list output only)
    #
    #################################################################################
    
    # string
    def string_input(object_name, attribute_name, options = {})
      text_field(object_name, attribute_name, options.merge(:size => "25"))
    end
    
    def string_output(content, attribute_name)
      output = content.send(attribute_name)
      (output.is_a? Array) ? output.size : output.to_s
    end
    
    # text
    def text_input(object_name, attribute_name, options = {})
      text_area(object_name, attribute_name, 
      	options.merge(:style => "width: 100%", :rows => 4))
    end
    
    def text_output(content, attribute_name)
      content.send(attribute_name).to_s.gsub("\n", "<br />")
    end
    
    # integer
    def integer_input(object_name, attribute_name, options = {})
      text_field(object_name, attribute_name, options.merge(:size => "5"))
    end
    
    def integer_output(content, attribute_name)
      content.send(attribute_name).to_s
    end    
    
    # decimal
    def decimal_input(object_name, attribute_name, options = {})
      text_field(object_name, attribute_name, options.merge(:size => "5"))
    end
    
    def decimal_output(content, attribute_name)
      content.send(attribute_name).to_s
    end    
    
    # boolean
    def boolean_input(object_name, attribute_name, options = {})
      check_box(object_name, attribute_name, options)
    end
    
    def boolean_output(content, attribute_name)
      content.send(attribute_name) ? "yes" : (content.send(attribute_name).nil? ? "" : "no")
    end
    
    # date
    def date_input(object_name, attribute_name, options = {})
      if options[:default_year] && # set default year for new records if one exists
        (object = instance_variable_get("@#{object_name}")).new_record?
        object.send("#{attribute_name}=", options[:default_year].to_i)
      end
      fix_name(date_select(object_name, attribute_name, :include_blank => true,
                :start_year => (options[:start_year] ? options[:start_year].to_i : 1901),
                :end_year => (options[:end_year] ? options[:end_year].to_i : 2099)),
                object_name, attribute_name, options)
    end
    
    def date_output(content, attribute_name)
      content.send(attribute_name).blank? ? "" : content.send(attribute_name).to_s(:long) 
    end
    
    # belongs_to (is ajaxable)
    def belongs_to_input(object_name, attribute_name, options = {})
      wrapper = "#{get_unique_tag}_#{attribute_name}_wrapper"
      content_tag(:div, build_belongs_to_input(object_name, attribute_name, 
                              options.merge(:wrapper => wrapper)),
                  :id => wrapper)
    end
    
    def belongs_to_output(content, attribute_name)
      name_of(content.send(Crud.get_association(content.class.name,attribute_name).name))
    end

    # simple_list
    def simple_list_input(object_name, attribute_name, options = {})
      items = instance_variable_get("@#{object_name}").selection_choices_for(attribute_name)
      return "list is empty" if items.blank?
      return  fix_name(select(object_name, attribute_name, items, :include_blank => true),
                      object_name, attribute_name, options)
    end
    
    def simple_list_output(content, attribute_name)  
      #return "" unless (item = content.simple_list_item_for(attribute_name))
      return "" unless (item = content.send(Crud.get_association(
      													content.class.name,attribute_name).name))
      item.name_with_url
    end
    
    # multi_simple_list
    def multi_simple_list_input(object_name, attribute_name, options = {})
      wrapper = "#{get_unique_tag}_#{attribute_name}_wrapper"
      content_tag(:div, build_multi_simple_list_input(object_name, attribute_name, 
                              options.merge(:wrapper => wrapper)),
                  :id => wrapper)
    end
    
    def multi_simple_list_output(content, attribute_name)
      multi_select_display(content, attribute_name).to_s
    end
    
    # multi_simple_list_list
    def multi_simple_list_list_input(object_name, attribute_name, options = {})
      text_field(object_name, attribute_name, options.merge(:size => "25"))
    end
    
    def multi_simple_list_list_output(content, attribute_name)
      multi_select_display(content, attribute_name).to_s
    end
    
    # price
    def price_input(object_name, attribute_name, options = {})
      "$" + text_field(object_name, attribute_name, options.merge(:size => "10"))
    end
    
    def price_output(content, attribute_name)
      number_to_currency(content.send(attribute_name).to_f)
    end
    
    # percentage
    def percentage_input(object_name, attribute_name, options = {})
      text_field(object_name, attribute_name, options.merge(:size => "5")) + "%"
    end
    
    def percentage_output(content, attribute_name)
      number_to_percentage(content.send(attribute_name).to_f, :precision => 2)
    end
    
    # has_many    
    def has_many_output(content, attribute_name)
      content.send(attribute_name).count.to_s
    end
    
    # error catchers
    def invalid_input(object_name, attribute_name, options = {})
      "BUG: #{object_name} does not respond to '#{attribute_name}'"
    end
    
    def invalid_output(content, attribute_name)
      "BUG: #{content.class.name} does not respond to '#{attribute_name}'"
    end
    
    def _input(object_name, attribute_name, options = {})
      "BUG: #{object_name}, #{attribute_name}"
    end
    
    def _output(content, attribute_name)
      "BUG: #{content.class.name}, #{attribute_name}"
    end
    
    
    # *** RAILS BUG *** select helper ignores the html :name => option
    def fix_name(select_tag, object_name, attribute_name, options = {})
      return select_tag unless options[:name]
      nested_name = /\[#{attribute_name}\]/.match(options[:name]).pre_match
      return select_tag.gsub(/name="#{object_name}/,"name=\"#{nested_name}")
    end
    
  end

end
