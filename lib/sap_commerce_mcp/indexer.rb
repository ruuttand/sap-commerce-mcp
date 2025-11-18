# frozen_string_literal: true

require 'sqlite3'
require 'digest'

module SapCommerceMcp
  class Indexer
    attr_reader :project_path, :db_path, :db

    def initialize(project_path)
      @project_path = File.expand_path(project_path)
      @parser = Parser::SapCommerceParser.new(@project_path)
      
      # Create index database in user's data directory
      project_hash = Digest::MD5.hexdigest(@project_path)[0..8]
      @db_path = File.join(SapCommerceMcp.data_dir, 'indexes', "#{project_hash}.db")
      FileUtils.mkdir_p(File.dirname(@db_path))
    end

    def build_index
      start_time = Time.now
      
      open_db
      initialize_schema
      
      extensions = @parser.find_extensions
      
      stats = {
        classes_count: 0,
        methods_count: 0,
        annotations_count: 0,
        beans_count: 0,
        files_processed: 0,
        extensions_count: extensions.size
      }

      @db.execute('BEGIN TRANSACTION')

      begin
        extensions.each do |extension|
          index_extension(extension, stats)
        end

        # Store metadata
        @db.execute('INSERT OR REPLACE INTO index_metadata (key, value) VALUES (?, ?)',
                   'last_indexed', Time.now.to_i.to_s)
        @db.execute('INSERT OR REPLACE INTO index_metadata (key, value) VALUES (?, ?)',
                   'project_path', @project_path)

        @db.execute('COMMIT')
      rescue => e
        @db.execute('ROLLBACK')
        raise e
      end

      stats[:duration_seconds] = Time.now - start_time
      stats
    end

    def index_exists?
      File.exist?(@db_path)
    end

    def last_indexed_time
      return nil unless index_exists?
      
      open_db unless @db
      result = @db.get_first_value('SELECT value FROM index_metadata WHERE key = ?', 'last_indexed')
      result ? Time.at(result.to_i) : nil
    end

    def get_stats
      open_db unless @db

      {
        last_indexed: last_indexed_time&.strftime('%Y-%m-%d %H:%M:%S'),
        classes_count: @db.get_first_value('SELECT COUNT(*) FROM classes'),
        methods_count: @db.get_first_value('SELECT COUNT(*) FROM methods'),
        annotations_count: @db.get_first_value('SELECT COUNT(*) FROM annotations'),
        beans_count: @db.get_first_value('SELECT COUNT(*) FROM spring_beans'),
        extensions_count: @db.get_first_value('SELECT COUNT(DISTINCT extension) FROM classes'),
        index_size_bytes: File.size(@db_path)
      }
    end

    def ensure_db_open
      open_db unless @db
    end

    def close
      @db&.close
      @db = nil
    end

    private

    def open_db
      @db = SQLite3::Database.new(@db_path)
      @db.results_as_hash = true
    end

    def initialize_schema
      @db.execute_batch(<<~SQL)
        DROP TABLE IF EXISTS classes;
        DROP TABLE IF EXISTS class_interfaces;
        DROP TABLE IF EXISTS methods;
        DROP TABLE IF EXISTS annotations;
        DROP TABLE IF EXISTS spring_beans;
        DROP TABLE IF EXISTS imports;
        DROP TABLE IF EXISTS index_metadata;

        CREATE TABLE classes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          simple_name TEXT NOT NULL,
          package TEXT NOT NULL,
          file_path TEXT NOT NULL,
          extension TEXT,
          type TEXT NOT NULL,
          parent_class TEXT,
          is_item_model INTEGER DEFAULT 0,
          last_modified INTEGER
        );

        CREATE INDEX idx_classes_name ON classes(name);
        CREATE INDEX idx_classes_simple_name ON classes(simple_name);
        CREATE INDEX idx_classes_extension ON classes(extension);
        CREATE INDEX idx_classes_type ON classes(type);

        CREATE TABLE class_interfaces (
          class_id INTEGER,
          interface_name TEXT,
          FOREIGN KEY(class_id) REFERENCES classes(id)
        );

        CREATE INDEX idx_class_interfaces_class_id ON class_interfaces(class_id);
        CREATE INDEX idx_class_interfaces_interface_name ON class_interfaces(interface_name);

        CREATE TABLE methods (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          class_id INTEGER,
          name TEXT NOT NULL,
          signature TEXT NOT NULL,
          return_type TEXT,
          modifiers TEXT,
          is_constructor INTEGER DEFAULT 0,
          FOREIGN KEY(class_id) REFERENCES classes(id)
        );

        CREATE INDEX idx_methods_class_id ON methods(class_id);
        CREATE INDEX idx_methods_name ON methods(name);

        CREATE TABLE annotations (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          target_type TEXT,
          target_id INTEGER,
          annotation_name TEXT NOT NULL,
          annotation_value TEXT
        );

        CREATE INDEX idx_annotations_name ON annotations(annotation_name);
        CREATE INDEX idx_annotations_target ON annotations(target_type, target_id);

        CREATE TABLE spring_beans (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          bean_id TEXT NOT NULL,
          class_name TEXT,
          parent_bean TEXT,
          scope TEXT,
          extension TEXT,
          file_path TEXT
        );

        CREATE INDEX idx_spring_beans_bean_id ON spring_beans(bean_id);
        CREATE INDEX idx_spring_beans_class_name ON spring_beans(class_name);

        CREATE TABLE imports (
          class_id INTEGER,
          imported_class TEXT,
          FOREIGN KEY(class_id) REFERENCES classes(id)
        );

        CREATE INDEX idx_imports_class_id ON imports(class_id);
        CREATE INDEX idx_imports_imported_class ON imports(imported_class);

        CREATE TABLE index_metadata (
          key TEXT PRIMARY KEY,
          value TEXT
        );
      SQL
    end

    def index_extension(extension, stats)
      # Index Java files
      java_files = @parser.find_java_files(extension[:path])
      java_files.each do |file|
        index_java_file(file, extension[:name], stats)
        stats[:files_processed] += 1
      end

      # Index Spring XML files
      spring_files = @parser.find_spring_xml_files(extension[:path])
      spring_files.each do |file|
        index_spring_file(file, extension[:name], stats)
      end
    end

    def index_java_file(file_path, extension_name, stats)
      parsed = @parser.parse_java_file(file_path)
      return unless parsed && parsed[:class_info]

      class_info = parsed[:class_info]
      package = parsed[:package]
      full_name = package ? "#{package}.#{class_info[:name]}" : class_info[:name]

      # Insert class
      @db.execute(
        <<~SQL,
          INSERT INTO classes (name, simple_name, package, file_path, extension, type,
                              parent_class, is_item_model, last_modified)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        SQL
        full_name, class_info[:name], package || '', file_path, extension_name,
        class_info[:type], class_info[:extends], parsed[:is_item_model] ? 1 : 0,
        File.mtime(file_path).to_i
      )
      
      class_id = @db.last_insert_row_id
      stats[:classes_count] += 1

      # Insert interfaces
      class_info[:implements]&.each do |interface|
        @db.execute('INSERT INTO class_interfaces (class_id, interface_name) VALUES (?, ?)',
                   class_id, interface.strip)
      end

      # Insert methods
      parsed[:methods]&.each do |method|
        @db.execute(
          <<~SQL,
            INSERT INTO methods (class_id, name, signature, return_type, modifiers, is_constructor)
            VALUES (?, ?, ?, ?, ?, ?)
          SQL
          class_id, method[:name], method[:signature], method[:return_type],
          method[:modifiers].join(' '), method[:is_constructor] ? 1 : 0
        )
        
        method_id = @db.last_insert_row_id
        stats[:methods_count] += 1

        # Insert method annotations
        method[:annotations]&.each do |annotation|
          @db.execute('INSERT INTO annotations (target_type, target_id, annotation_name) VALUES (?, ?, ?)',
                     'method', method_id, annotation)
          stats[:annotations_count] += 1
        end
      end

      # Insert class annotations
      parsed[:annotations]&.each do |annotation|
        @db.execute('INSERT INTO annotations (target_type, target_id, annotation_name, annotation_value) VALUES (?, ?, ?, ?)',
                   'class', class_id, annotation[:name], annotation[:value])
        stats[:annotations_count] += 1
      end

      # Insert imports
      parsed[:imports]&.each do |import|
        @db.execute('INSERT INTO imports (class_id, imported_class) VALUES (?, ?)',
                   class_id, import)
      end

    rescue => e
      warn "Error indexing #{file_path}: #{e.message}"
    end

    def index_spring_file(file_path, extension_name, stats)
      beans = @parser.parse_spring_xml(file_path)
      
      beans.each do |bean|
        next unless bean[:id] # Skip beans without ID
        
        @db.execute(<<~SQL, bean[:id], bean[:class], bean[:parent], bean[:scope], extension_name, file_path)
          INSERT INTO spring_beans (bean_id, class_name, parent_bean, scope, extension, file_path)
          VALUES (?, ?, ?, ?, ?, ?)
        SQL
        
        stats[:beans_count] += 1
      end
    rescue => e
      warn "Error indexing Spring file #{file_path}: #{e.message}"
    end
  end
end