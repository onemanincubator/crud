# requirements for mixins
require 'action_controller'
require 'action_view'

# mixins
require 'mixins/crud_model'
ActiveRecord::Base.class_eval {include Crud::ModelMethods}
require 'mixins/crud_helper'
ActionView::Base.module_eval {include Crud::HelperMethods}
require 'mixins/crud_controller'
ActionController::Base.class_eval {include Crud::ControllerMethods}
require 'mixins/crud_config_controller'
require 'mixins/crud_config_helper'
ActionView::Base.module_eval {include Crud::Config::HelperMethods}
ActionController::Base.class_eval {include Crud::Config::ControllerMethods}

# class methods
require 'class_methods/crud_class_methods'
require 'class_methods/crud_tools'

# models
require 'models/crud_attribute'
require 'models/crud_config'

module Crud
end



