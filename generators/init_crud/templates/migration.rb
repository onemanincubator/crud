class CreateCrudConfig < ActiveRecord::Migration
  def self.up
    create_table :crud_configs do |t|
      t.references  :model_name, :controller_name, :action_name
      t.timestamps
    end
    
    create_table :crud_attributes do |t|
      t.references  :attribute_name, :crud_config
      t.integer			:position
      t.text				:options
    end
           
    add_index :crud_configs, 
    					[:model_name_id, :controller_name_id, :action_name_id],
    					:name => 'config'			
  end
  
  def self.down
    drop_table :crud_configs
    drop_table :crud_attributes
  end
end

