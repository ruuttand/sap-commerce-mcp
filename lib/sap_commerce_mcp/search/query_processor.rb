# frozen_string_literal: true

module SapCommerceMcp
  module Search
    class QueryProcessor
      def initialize(db)
        @db = db
        @db.results_as_hash = true
      end

      def search_classes(query, filters = {}, limit = 50)
        sql = build_class_search_sql(query, filters, limit)
        @db.execute(sql[:query], *sql[:params])
      end

      def get_class_signature(class_name, include_inherited = false)
        # Get class basic info
        class_info = @db.get_first_row(<<~SQL, class_name)
          SELECT c.*, GROUP_CONCAT(ci.interface_name, ', ') as interfaces
          FROM classes c
          LEFT JOIN class_interfaces ci ON c.id = ci.class_id
          WHERE c.name = ?
          GROUP BY c.id
        SQL

        return nil unless class_info

        # Get methods
        methods = @db.execute(<<~SQL, class_info['id'])
          SELECT m.*, GROUP_CONCAT(a.annotation_name, ', ') as annotations
          FROM methods m
          LEFT JOIN annotations a ON a.target_type = 'method' AND a.target_id = m.id
          WHERE m.class_id = ?
          GROUP BY m.id
          ORDER BY m.name
        SQL

        # Get class annotations
        annotations = @db.execute(<<~SQL, class_info['id'])
          SELECT annotation_name, annotation_value
          FROM annotations
          WHERE target_type = 'class' AND target_id = ?
        SQL

        {
          class: class_info,
          methods: methods,
          annotations: annotations
        }
      end

      def find_implementations(class_or_interface, limit = 100)
        # Find classes that extend or implement the given class/interface
        results = []

        # Check by parent class
        results += @db.execute(<<~SQL, class_or_interface, limit)
          SELECT * FROM classes
          WHERE parent_class = ?
          LIMIT ?
        SQL

        # Check by interface
        results += @db.execute(<<~SQL, class_or_interface, limit - results.size)
          SELECT DISTINCT c.*
          FROM classes c
          JOIN class_interfaces ci ON c.id = ci.class_id
          WHERE ci.interface_name = ?
          LIMIT ?
        SQL

        results.uniq { |r| r['id'] }
      end

      def find_usages(class_name, limit = 100)
        # Find files that import this class
        pattern = "#{class_name.split('.').last}%"
        @db.execute(<<~SQL, class_name, pattern, limit)
          SELECT DISTINCT c.name, c.file_path, c.extension
          FROM classes c
          JOIN imports i ON c.id = i.class_id
          WHERE i.imported_class = ? OR i.imported_class LIKE ?
          LIMIT ?
        SQL
      end

      def search_annotations(annotation_name, target_type = 'all', limit = 100)
        case target_type
        when 'class'
          search_class_annotations(annotation_name, limit)
        when 'method'
          search_method_annotations(annotation_name, limit)
        when 'field'
          search_field_annotations(annotation_name, limit)
        when 'all'
          {
            classes: search_class_annotations(annotation_name, limit / 3),
            methods: search_method_annotations(annotation_name, limit / 3),
            fields: search_field_annotations(annotation_name, limit / 3)
          }
        end
      end

      def search_spring_beans(bean_id_pattern, extension = nil, limit = 50)
        sql = <<~SQL
          SELECT * FROM spring_beans
          WHERE bean_id LIKE ?
        SQL

        params = [convert_pattern(bean_id_pattern)]

        if extension
          sql += ' AND extension = ?'
          params << extension
        end

        sql += ' LIMIT ?'
        params << limit

        @db.execute(sql, *params)
      end

      private

      def build_class_search_sql(query, filters, limit)
        sql_parts = ['SELECT DISTINCT c.*']
        from_parts = ['FROM classes c']
        where_parts = []
        params = []

        # Build search condition
        if query.include?('*')
          where_parts << 'c.name LIKE ? OR c.simple_name LIKE ?'
          pattern = convert_pattern(query)
          params << pattern << pattern
        else
          where_parts << '(c.name LIKE ? OR c.simple_name LIKE ?)'
          params << "%#{query}%" << "%#{query}%"
        end

        # Add filters
        if filters['type']
          where_parts << 'c.type = ?'
          params << filters['type']
        end

        if filters['extension']
          where_parts << 'c.extension = ?'
          params << filters['extension']
        end

        if filters['is_item_model']
          where_parts << 'c.is_item_model = 1'
        end

        if filters['annotation']
          annotation_name = filters['annotation'].sub(/^@/, '')
          from_parts << 'JOIN annotations a ON a.target_type = "class" AND a.target_id = c.id'
          where_parts << 'a.annotation_name = ?'
          params << annotation_name
        end

        # Combine SQL
        sql = sql_parts.join(' ') + ' ' + from_parts.join(' ')
        sql += ' WHERE ' + where_parts.join(' AND ') unless where_parts.empty?
        sql += ' ORDER BY c.simple_name LIMIT ?'
        params << limit

        { query: sql, params: params }
      end

      def search_class_annotations(annotation_name, limit)
        @db.execute(<<~SQL, annotation_name, limit)
          SELECT c.name, c.simple_name, c.type, c.extension, c.file_path, a.annotation_value
          FROM classes c
          JOIN annotations a ON a.target_type = 'class' AND a.target_id = c.id
          WHERE a.annotation_name = ?
          LIMIT ?
        SQL
      end

      def search_method_annotations(annotation_name, limit)
        @db.execute(<<~SQL, annotation_name, limit)
          SELECT c.name as class_name, m.name as method_name, m.signature,
                 c.file_path, a.annotation_value
          FROM methods m
          JOIN annotations a ON a.target_type = 'method' AND a.target_id = m.id
          JOIN classes c ON m.class_id = c.id
          WHERE a.annotation_name = ?
          LIMIT ?
        SQL
      end

      def search_field_annotations(annotation_name, limit)
        @db.execute(<<~SQL, annotation_name, limit)
          SELECT c.name as class_name, c.file_path, a.annotation_value
          FROM annotations a
          JOIN classes c ON a.target_type = 'field' AND c.id IN (
            SELECT class_id FROM methods WHERE id = a.target_id
          )
          WHERE a.annotation_name = ?
          LIMIT ?
        SQL
      end

      def convert_pattern(pattern)
        # Convert glob pattern to SQL LIKE pattern
        pattern.gsub('*', '%').gsub('?', '_')
      end
    end
  end
end
