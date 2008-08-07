module Crud
  
  module ControllerMethods
    
    def self.included(base) #:nodoc:
      base.extend(ClassMethods)
    end

    module ClassMethods 
      def runs_like_crud(options={})
        
        cattr_accessor :read_only, :admin, :drafts, :table
        self.read_only = (options[:access] == 'read_only')
        self.admin = options[:admin]
        self.drafts = options[:drafts]
        self.table = options[:table]
        
        include Crud::ControllerMethods::InstanceMethods
        
        # GETs should be safe (see http://www.w3.org/2001/tag/doc/whenToUseGet.html)
        verify :method => :post, :only => :create, :redirect_to => { :action => :list }
        verify :method => :put, :only => :update, :redirect_to => { :action => :list }    
        verify :method => :delete, :only => :destroy, :redirect_to => { :action => :list }

      end
    end

    module InstanceMethods
      
      #################################################################################
      #
      # Main CRUD methods: list, show, new, create, edit, update, destroy, cancel
      #
      #################################################################################
      
      def list
        list_ajax and return if request.xhr? # punt ajax requests
        return unless (@table = which_table)
        order = params[:order] || ('created_at DESC' if 
                          @table.constantize.column_names.include?('created_at'))
        options = {:page => params[:page] || 1, :per_page => 10, :order => order}
        return unless (host_options = options_for_find_list(@table, options))
        @content_list = @table.constantize.paginate(options.merge(host_options))
        render and return if default_template_exists        
        render_template('list')
      end

      def show
        crud
      end

      def new
        crud
      end

      def create
      	crud_save
      end
      
      def edit
        crud
      end

      def update
      	crud_save
     	end
     	
      def destroy
        destroy_ajax and return if request.xhr? # punt ajax requests
        return unless (@table = which_table)
        @content = get_content(@table)
        redirect_to_index and return unless @content.is_a? @table.constantize
        @content.destroy
        redirect_to_index and return unless params[:table]
        redirect_to :action => 'list', :table => params[:table]
      end
      
      def cancel
        cancel_ajax and return if request.xhr? # punt ajax requests 
        if params[:id] && params[:table]
          redirect_to :action => 'show', :id => params[:id], :table => params[:table]
        elsif params[:id]
          redirect_to :action => 'show', :id => params[:id]
        elsif params[:table]
          redirect_to :action => 'list', :table => params[:table]
        else
          redirect_to_index
        end
      end

      #################################################################################
      #
      # Ajax counterparts to the CRUD methods
      #
      #################################################################################
      
      def list_ajax
        return unless (@table = which_table)
        wrapper = params[:wrapper] || "#{@table.tableize}_list_wrapper"
        order = params[:order] || ('created_at DESC' if 
                          @table.constantize.column_names.include?('created_at'))
        options = {:page => params[:page] || 1, :per_page => 10, :order => order}
        host_options = options_for_find_list(@table, options)
        @content_list = @table.constantize.paginate(options.merge(host_options))
        render :update do |page|
          page.replace_html wrapper, list_items_tag
        end
      end
      
      def show_ajax
      end
      
      def new_ajax
        # gather core options from params (they orginate from link_to_new_remote)
        options = Hash[*%w(attribute_name context wrapper name table).map {|opt| 
                        [opt.to_sym, params[opt.to_sym]]}.flatten]
        
        # merge in context-specific options
        case options[:context]         
        when 'read_has_many'
          options.merge!( :input_form =>    true,
                          :parent_type =>   params[:parent_type], 
                          :parent_id =>     params[:parent_id])
        when 'belongs_to'
          options.merge!( :input_form =>    true,
                          :object_name =>   params[:object_name],
                          :object_id =>     params[:object_id])
        when 'multi_simple_list'
          options.merge!( :input_form =>    true,
                          :object_name =>   params[:object_name],
                          :object_id =>     params[:object_id])          
        when 'form_has_many'
          options.merge!( :no_buttons =>    true)
          # need to complete the merge at render time since the merge calls a view method
          form_has_many = true
        end
        
        # render the new subform
        content = options[:table].tableize.classify.constantize.new 
        render :update do |page|
          page.insert_html :bottom, options[:wrapper], 
              wrapped_form(content, 'new', form_has_many ? 
              options.merge(:name => "#{options[:name]}[#{get_unique_tag}]") : options)
        end
      end
      
      def create_ajax
        # Create the content
        object = params[:table].classify.constantize.new(
                  params["#{params[:table].classify.underscore}"])
        # NOTE: Although valid? clears errors, subforms could slip in more errors after
        # valid? has completed (see crud_model)
        raise ActiveRecord::RecordInvalid, object unless object.valid? && object.errors.empty?
        object.save 
        
        # Render it
        case params[:context]
        when 'read_has_many'
          params[:parent_type].tableize.classify.constantize.find(
              params[:parent_id]).send(params[:attribute_name]) << object
          render :update do |page|
            page.replace_html params[:wrapper], read(object, 'show')
          end
          
        when 'belongs_to'
          wrapper = /\d+?_/.match(params[:wrapper]).post_match
          render :update do |page|
            page.replace_html wrapper, build_belongs_to_input(
                      params[:object_name], params[:attribute_name], 
                      :wrapper => wrapper,
                      :name =>  params[:name],
                      :belongs_to_id => object.id)
          end

        when 'multi_simple_list'
          unless object.simple_list_list_id
            attribute_name = params[:attribute_name]
            list_name = /_id\z/ =~ attribute_name ? attribute_name[0..-4] : attribute_name
            SimpleListList.find_or_create(list_name).insert_item(object)
          end
          wrapper = /\d+?_/.match(params[:wrapper]).post_match
          render :update do |page|
            page.replace_html wrapper, build_multi_simple_list_input(
                      params[:object_name], params[:attribute_name], 
                      :wrapper => wrapper,
                      :name =>  params[:name])
          end
        end
      rescue ActiveRecord::RecordInvalid => e
        render :update do |page|
          page.alert e.record.errors.full_messages.join(", ")
        end
      end
      
      def edit_ajax
        content = params[:table].tableize.classify.constantize.find(params[:id])
        render :update do |page|
          page.replace_html params[:wrapper], input_form(content, 'edit', 
                                                        :wrapper => params[:wrapper],
                                                        :table =>   params[:table])
        end 
      end
      
      def update_ajax
        content = params[:table].constantize.find(params[:id])
        content.update_attributes!(params["#{params[:table].tableize.classify.underscore}"])
        render :update do |page|
          page.replace_html params[:wrapper], read_subform(content, 'show')
        end
      rescue ActiveRecord::RecordInvalid => e
        render :update do |page|
          page.alert e.record.errors.full_messages.join(", ")
        end
      end
      
      def cancel_ajax
        if params[:context].nil? # coming in from edit
          content = params[:table].tableize.classify.constantize.find(params[:id]) if params[:id]
          render :update do |page|
            page.replace_html params[:wrapper], content ? read_subform(content, 'show') : nil
          end
        else # coming in from one of the 'new' methods
          close_ajax
        end          
      end
      
      def close_ajax
        render :update do |page|
          page.remove params[:wrapper]
        end
      end
      
      def destroy_ajax
        params[:table].tableize.classify.constantize.find(params[:id]).destroy
        render :update do |page|
          page.replace_html params[:wrapper], nil
        end
      end
      
      def manage_list_ajax
        list = params[:content_type].constantize.find(params[:content_id])
        case params[:ajax_action]
        when 'move_up'
          list.send(params[:items_method]).find(params[:item_id]).move_higher
        when 'move_down'
          list.send(params[:items_method]).find(params[:item_id]).move_lower
        #when 'delete'
        #  list.simple_list_items.find(params[:item_id]).destroy
        end
        #list.send(items_name, true)
        render :update do |page|
          page.replace params[:wrapper], 
          							manage_list(list, params[:items_method])
        end
      end
      
      private
      
      # performs show, new, and edit
      def crud
        self.send("#{action_name}_ajax") and return if request.xhr? # punt ajax requests
        raise ActiveRecord::RecordNotFound unless params[:id] || action_name == 'new'
        return unless (@table = which_table)        
        @content = get_content(@table)        
        raise ActiveRecord::RecordNotFound unless @content.is_a? @table.constantize
        render and return if default_template_exists
        render_template(action_name)
      rescue ActiveRecord::RecordNotFound
        flash[:notice] = "Sorry, could not find #{@table} #{params[:id]}"
        redirect_to :action => 'list', :table => params[:table]
      end
      
      # performs create, and update
      def crud_save
        self.send("#{action_name}_ajax") and return if request.xhr? # punt ajax requests
        return unless (@table = which_table)
        redirect_to_cancel and return if action_was_cancelled?
        send("crud_#{action_name}")
        @content.post if @content.respond_to?('post') && (params[:commit] == 'Post')
        params[:commit] == 'Save and Preview' ? # in case drafts allowed
        	redirect_to(:action => 'edit', :id => @content, :table => params[:table]) :
        	redirect_to(:action => 'show', :id => @content, :table => params[:table])
      rescue ActiveRecord::RecordInvalid => e
      	flash[:content] = @content
        flash[:notice] = "Save failed because this form has errors (see below)"
        # do redirects to preserve RESTful urls
        @content.new_record? ? 
        	redirect_to(:action => 'new', :table => params[:table]) :
        	redirect_to(:action => 'edit', :table => params[:table])
      end
      
      def crud_create
        content_params = params["#{@table.underscore}"]
        @content = @table.constantize.new(content_params)
        # NOTE: Although valid? clears errors, subforms could slip in more errors after
        # valid? has completed (see crud_model)
        raise ActiveRecord::RecordInvalid, @content unless @content.valid? && @content.errors.empty?
        @content.save # Save the content
      end
      
      def crud_update
        @content = @table.constantize.find(params[:id]) # Generate the content
        @content.update_attributes!(params["#{@table.underscore}"]) # update the content
      end    
      
      # return the table on which crud methods are operating
      def which_table
      	table = params[:table] # try param first
      	unless table
      		@no_param = true
      		# then try instance variable, class variable, and url
      		table = @table || self.table || request.path.split('/')[1]
      	end
      	table = table.tableize.classify 
        model = table.constantize # a valid class? 
        model.connected? and !model.abstract_class? # tied to db?
        table
      rescue
        flash[:notice] = "crud can't process '#{table}'; use the :table param"
        redirect_to_index and return false
      end     
      
      # can be over-ridden by the host controller
      def options_for_find_list(model_name, options = {})
        options
      end
      
      def get_content(model_name, options = {})
        return unless %w(show edit new destroy).include?(action_name)
        return flash[:content] if flash[:content]
        params[:id] ?   
        	model_name.constantize.find(params[:id]) : 
          model_name.constantize.new(options)
      end
      
      def default_template_exists(options={})
        action = options[:action] || params[:action] # params[:action] could be 'submit_crud'
        return false unless params[:controller] && action
        views_dir = File.join(RAILS_ROOT,'app','views',params[:controller])
        %w(rhtml rjs rxml).each do |ext| # use the default template if it exists
          return true if File.exist?(File.join(views_dir,"#{action}.#{ext}"))
        end
        return false
      end
      
      def render_action(action_name)
        render :action => action_name and return if default_template_exists(:action => action_name)
       	render_template(action_name)
      end
      
      # renders the plugin default template
      def render_template(action_name)
				render :file => "#{File.dirname(__FILE__)}/../templates/#{action_name}.rhtml", 
								:layout => true
      end
      
      def redirect_to_index
        redirect_to :action => 'index'
      end
      
      def redirect_to_cancel
        redirect_to :action => 'cancel', :table => params[:table], :id => params[:id]
      end
      
      def action_was_cancelled?
        params[:commit] == 'Cancel'
      end
      
      def action_was_continued?
        params[:commit] == 'Create and Continue'
      end

    end
  end
end
