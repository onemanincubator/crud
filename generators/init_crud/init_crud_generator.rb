class InitCrudGenerator < Rails::Generator::Base
  
  def manifest
    record do |m|
      puts ""
      
      # TODO: Move this to a new "initialize site" vendor/generator
      ## create admin controller and index view for managing app databases
      #Rails::Generator::Scripts::Generate.new.run(['controller','admin'])
      #m.directory File.join('app','views','admin')
      #m.file 'admin/index.rhtml', File.join('app','views','admin','index.rhtml')

      # create initial layouts view for the app
      #m.directory File.join('app','views','layouts')
      #m.file 'layouts/_header.rhtml', File.join('app','views','layouts','_header.rhtml')
      #m.file 'layouts/_footer.rhtml', File.join('app','views','layouts','_footer.rhtml')
      #m.file 'layouts/_masthead.rhtml', File.join('app','views','layouts','_masthead.rhtml')    
      #m.file 'layouts/application.rhtml', File.join('app','views','layouts','application.rhtml')
			
      # crud_config
      m.migration_template 'migration.rb', 'db/migrate', :migration_file_name => 'create_crud_config'
      
      # print out README
      puts ""      
      puts IO.read(File.join(File.dirname(__FILE__),'..', '..', 'README'))    
    end  
  end
  
end
