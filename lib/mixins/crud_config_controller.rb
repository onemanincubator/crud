module Crud

	module Config
  
	  module ControllerMethods
    
    	def self.included(base)
      	base.extend(ClassMethods)
    	end

    	module ClassMethods
    	 
      	def runs_like_config(options={})
        	include Crud::Config::ControllerMethods::InstanceMethods
      	end
      	
    	end
    	
    	module InstanceMethods 
    		
	    	def show_config
	    		@crud_config = CrudConfig.find(params[:id]) unless 
	    			params[:id].blank?
	    		@crud_config ||= CrudConfig.find_only(params[:model_name_id], 
	    				params[:controller_name_id], params[:action_name_id])
	    		@crud_config ||= CrudConfig.new(
	    			:model_name_id => params[:model_name_id],
	    			:controller_name_id => params[:controller_name_id],
	    			:action_name_id => params[:action_name_id])
	    		render :update do |page|
	    			page.replace_html 'config_attributes_wrapper', show_config
	    		end
	    	end
	    
	    	def edit_config
	    		@crud_config = (params[:id].blank? ?
	    			CrudConfig.new(
	    				:model_name_id => params[:model_name_id],
	    				:controller_name_id => params[:controller_name_id],
	    				:action_name_id => params[:action_name_id]) :
	    			CrudConfig.find(params[:id]))
	    		render :update do |page|
	    			page.replace_html 'config_attributes_wrapper', edit_config
	    		end
	    	end
	    	
	    	def save_config
	    		@crud_config = params[:id].blank? ?
	    			CrudConfig.create!(params['crud_config']) :
						CrudConfig.find(params[:id])
					@crud_config.crud_attribute_names = params[:crud_attribute_names]
					redirect_to :action => 'show_config', :id => @crud_config
	    	end
	    	
	    end
    	
    end
  
  end
  
end
