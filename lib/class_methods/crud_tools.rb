#require "spreadsheet/excel" # writing excel
#include Spreadsheet # writing excel
#require 'parseexcel' # reading excel

module Crud
  
  class << self
    
    # Crud tools provide Crud class methods that can perform operations across 
    # multiple tables. These methods inlcude:
    #
    # - tables_list
    # - generate
    # - download
    
    #########################################################################################
    #
    # tables_list
    #
    #   Returns an array of names of the substantive tables used by the app.
    #
    #########################################################################################
    
    def tables_list
      ActiveRecord::Base.active_connections.values.map {|connection| 
      	connection.tables}.flatten - 
      	%w(schema_migrations schema_info sessions)
    end
    
    def app_tables_list
  	  # collect list of app-defined models
    	Dir.chdir("#{RAILS_ROOT}/app/models")
			app_tables = Dir['*.rb'].map {|fn| fn.gsub(/\.rb/, "").tableize}
			# intersect above list with list of database tables
			(app_tables & tables_list).sort
    end
    
    # returns list of app controllers located at the top level of 
    # app/controllers
    def app_controllers_list
    	controllers = Dir.new("#{RAILS_ROOT}/app/controllers").entries
			controllers.map {|c| c.camelize.gsub(".rb","") if
													c =~ /_controller.rb/}.compact.sort
		end
    
    #########################################################################################
    #
    # generate(table, number, options = {})
    #
    #   Generates 'number' records for table 'table'.
    #
    #########################################################################################
    
    def generate(tables, numbers, options = {})
      # Prelimnary error checking
      return "tables must be an array" unless tables.is_a? Array
      return "numbers must be an array" unless numbers.is_a? Array
      return "tables and numbers are mismatched" unless tables.size == numbers.size
      all_tables = tables_list
      tables.each_with_index do |table,i|
        return "#{table.tableize} is not a valid table" unless 
          all_tables.include?(table.tableize)
        return "all numbers must be > 0" unless numbers[i].to_i > 0
      end
      
      # Generate records for each of the tables
      tables.each_with_index do |table,i|
        # extract columns to populate
        table = table.classify
        columns_hash = get_columns_hash(table, 'generate', 'default')
        return ":has_many columns not permitted (#{table.tableize})" unless 
                             columns_hash['_hm_attributes'].blank?

        # setup possible values
        columns_hash.delete('_attributes')
        columns_hash.delete('_hm_attributes')
        instance_variable_set("@#{table.underscore}", table.constantize.new)
        columns_hash.each do |k,v|
          case v[:type]
          when "belongs_to"
            r = {:array => get_association(table.classify, k).table_name.classify.constantize.find(
                                  :all).map(&:id).compact}
          when "simple_list"
            list_name = table.constantize.send("#{k}_selection_list")
            r = {:array => SimpleListList.find_or_create(list_name).simple_list_items.map(&:id)}
          when "multi_simple_list"
            list_name = /_id\z/ =~ k ? k[0..-4] : k
            r = {:array => SimpleListList.find_or_create(list_name).simple_list_items.map(&:id),
                  :multi => (v['multi'] || 3)}
          when "multi_simple_list_list"
            list_name = /_list\z/ =~ k ? k[0..-6] : k
            r = {:array => SimpleListList.find_or_create(list_name).simple_list_items.map(&:name),
                  :multi => (v['multi'] || 3), :list => true}
          when "price"
            r = {:start => (v['start'] || 10), 
                :end => (v['end'] || 20000000)}
          when "percentage"
            r = {:start => (v['start'] || 0), 
                :end => (v['end'] || 20)}
          when "boolean"
            r = {:start => 0, :end => 1}
          when "date"
            r = {:start => (v['start'] || '1/1/1990').to_date, 
                :end => (v['end'] || '1/1/2008').to_date}
          when "integer"
            r = {:start => (v['start'] || 0), 
                :end => (v['end'] || 100)}
          else # string or text (default)
          end
          r.merge!(:nil => v['nil']) if r && v['nil']
          columns[k] = r ? r : v[:type]
        end

        # generate the records 
        #return columns.to_a.flatten.join(' ')
        errors = 0
        numbers[i].to_i.times do
          attributes = Hash.new.merge(columns)
          attributes.each do |k, v|
            if v.is_a? Hash
              if v[:nil] && rand(v[:nil]) == 0
                r = nil
              elsif v[:start] && v[:end]
                r = v[:start] + rand(v[:end]-v[:start])
              elsif v[:array]
                if v[:multi]
                  choices = v[:array].map {|e| e.to_s}
                  size = choices.size
                  r = []
                  rand(v[:multi]+1).times do # get random subset (at least one)
                    r << choices[rand(choices.size)]
                    choices -= r
                  end
                  r = r.join(' ') if v[:list]              
                else
                  r = v[:array][rand(v[:array].size)]
                end
              end
            elsif v.is_a? String
              r = "test data"
            end
            attributes[k] = r ? r : nil
          end
          (object = table.constantize.new).attributes = attributes
          errors += 1 unless object.save
        end     
        numbers[i] -= errors
        
      end
        
      return numbers # array of number of records that were generated per table    
    end
    
    #########################################################################################
    #
    # export(tables, options = {})
    #
    #   Writes records from 'tables' into a file and return the path to that file
    #   to enable downloading (i.e. via send_file). Default file format is Excel.
    #
    #########################################################################################
    
    def export(tables, options = {})
      # Prelimnary error checking
      all_tables = tables_list
      if tables.first == "*"
        tables = all_tables 
      else
        return "tables must be an array" unless tables.is_a? Array
        tables.each do |table|
          return "#{table.tableize} is not a valid table" unless 
                  all_tables.include?(table.tableize)
        end
      end
      format = options[:format] || 'xls'  
      
      # Assuming we're downloading into excel for now
      
      # generate a new xls file
      file_path = "#{RAILS_ROOT}/tmp/hip_data_#{rand(100).to_s + Time.now.to_i.to_s}.#{format}"
      workbook = Excel.new(file_path)

      # populate the file
      tables.each do |table|
        # generate a new worksheet
        worksheet = workbook.add_worksheet(table)
        objects = table.classify.constantize.find(:all)
        columns, has_many_columns = Crud.columns_array(table.classify, 'download', format)
        
        # populate the column headings
        columns.each_with_index do |column, i|
          worksheet.write(0, i, column.first)
        end
        
        # populate the worksheet rows
        objects.each_with_index do |object, j|
          columns.each_with_index do |column, i|
            cell = object.send(column.first)
            worksheet.write(j+1, i, cell.respond_to?('name') ? cell.name : cell.to_s)
          end
        end
      end
      workbook.close
      file_path
    end
    
    #########################################################################################
    #
    # import(tables, options = {})
    #
    #
    #########################################################################################
    
    def import(xls_file, options = {})
      return "Error: '#{xls_file.original_filename}' is not an Excel file" unless
        /.+?\.xls$/ =~ xls_file.original_filename
      # TBD
    end
        
  end

end
