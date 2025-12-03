# frozen_string_literal: true

module SapCommerceMcp
  module Tools
    class FindInjectedDependencies < MCP::Tool
      title 'Find Injected Dependencies'

      description <<~DESC
        Analyze Spring field injection (@Autowired, @Resource, @Inject). Primary tool for SAP Commerce dependency analysis.

        TWO MODES (use one):
        1. class_name: "What does X depend on?" → finds @Autowired fields in that class
        2. injected_type: "What depends on X?" → finds classes injecting that type

        USE: "What services does DefaultCheckoutFacade use?", "What injects CheckoutService?", "Show dependencies of X"
        NOT: imports→FindUsages | XML beans→GetSpringBeans | subclasses→FindImplementations

        Returns: field name, type, annotations, containing class. Filter by annotation: Autowired/Resource/Inject.
      DESC

      input_schema(
        type: 'object',
        properties: {
          class_name: {
            type: 'string',
            description: 'Find dependencies injected INTO this class (fully qualified or simple name)'
          },
          injected_type: {
            type: 'string',
            description: 'Find all classes that inject this type (e.g., "CheckoutService")'
          },
          annotation: {
            type: 'string',
            description: 'Filter by specific annotation (e.g., "Autowired", "Resource", "Inject")'
          },
          limit: {
            type: 'integer',
            description: 'Maximum number of results (default: 100)',
            default: 100
          }
        }
      )

      class << self
        def call(class_name: nil, injected_type: nil, annotation: nil, limit: 100, server_context:)
          indexer = server_context[:indexer]
          audit_logger = server_context[:audit_logger]
          start_time = Time.now

          begin
            indexer.ensure_db_open
            db = indexer.db

            results = []

            if class_name
              # Find dependencies injected INTO this class
              results = find_dependencies_of_class(db, class_name, annotation, limit)
              result_text = format_dependencies_of_class(class_name, results)
            elsif injected_type
              # Find classes that inject this type
              results = find_classes_injecting_type(db, injected_type, annotation, limit)
              result_text = format_classes_injecting_type(injected_type, results)
            else
              return error_response('Must specify either class_name or injected_type')
            end

            duration_ms = (Time.now - start_time) * 1000
            audit_logger&.log_request(
              'find_injected_dependencies',
              { class_name: class_name, injected_type: injected_type, annotation: annotation, limit: limit },
              { result_count: results.size },
              duration_ms
            )

            MCP::Tool::Response.new([{
              type: 'text',
              text: result_text
            }])
          rescue => e
            audit_logger&.log_error('find_injected_dependencies', e)
            error_response(e.message)
          end
        end

        private

        def find_dependencies_of_class(db, class_name, annotation_filter, limit)
          # Build query to find all injected fields in this class
          query = <<~SQL
            SELECT
              f.name as field_name,
              f.type as field_type,
              f.modifiers,
              c.name as class_name,
              c.extension,
              GROUP_CONCAT(a.annotation_name ||
                CASE WHEN a.annotation_value IS NOT NULL
                     THEN '(' || a.annotation_value || ')'
                     ELSE ''
                END, ', ') as annotations
            FROM classes c
            INNER JOIN fields f ON c.id = f.class_id
            LEFT JOIN annotations a ON a.target_type = 'field' AND a.target_id = f.id
            WHERE (c.name LIKE ? OR c.simple_name LIKE ?)
          SQL

          if annotation_filter
            query += " AND a.annotation_name = ?"
            params = ["%#{class_name}%", "%#{class_name}%", annotation_filter]
          else
            # Only show fields that have injection annotations
            query += " AND a.annotation_name IN ('Autowired', 'Resource', 'Inject', 'Qualifier')"
            params = ["%#{class_name}%", "%#{class_name}%"]
          end

          query += <<~SQL
            GROUP BY f.id, f.name, f.type, c.name, c.extension
            LIMIT ?
          SQL

          params << limit

          db.execute(query, params)
        end

        def find_classes_injecting_type(db, injected_type, annotation_filter, limit)
          # Find all classes that have fields of this type with injection annotations
          query = <<~SQL
            SELECT
              c.name as class_name,
              c.simple_name,
              c.extension,
              c.file_path,
              f.name as field_name,
              f.type as field_type,
              GROUP_CONCAT(a.annotation_name ||
                CASE WHEN a.annotation_value IS NOT NULL
                     THEN '(' || a.annotation_value || ')'
                     ELSE ''
                END, ', ') as annotations
            FROM classes c
            INNER JOIN fields f ON c.id = f.class_id
            LEFT JOIN annotations a ON a.target_type = 'field' AND a.target_id = f.id
            WHERE (f.type LIKE ? OR f.type = ?)
          SQL

          if annotation_filter
            query += " AND a.annotation_name = ?"
            params = ["%#{injected_type}%", injected_type, annotation_filter]
          else
            query += " AND a.annotation_name IN ('Autowired', 'Resource', 'Inject', 'Qualifier')"
            params = ["%#{injected_type}%", injected_type]
          end

          query += <<~SQL
            GROUP BY c.id, f.id, c.name, c.simple_name, c.extension, f.name, f.type
            ORDER BY c.name
            LIMIT ?
          SQL

          params << limit

          db.execute(query, params)
        end

        def format_dependencies_of_class(class_name, results)
          return "No injected dependencies found for class: #{class_name}" if results.empty?

          output = ["# Injected Dependencies for: #{class_name}", ""]
          output << "Found #{results.size} injected field(s):"
          output << ""

          results.each do |row|
            output << "## Field: #{row['field_name']}"
            output << "- Type: #{row['field_type']}"
            output << "- Modifiers: #{row['modifiers']}" if row['modifiers'] && !row['modifiers'].empty?
            output << "- Annotations: #{row['annotations']}" if row['annotations']
            output << "- Extension: #{row['extension']}" if row['extension']
            output << ""
          end

          output.join("\n")
        end

        def format_classes_injecting_type(injected_type, results)
          return "No classes found injecting type: #{injected_type}" if results.empty?

          output = ["# Classes Injecting: #{injected_type}", ""]
          output << "Found #{results.size} injection point(s):"
          output << ""

          results.group_by { |r| r['class_name'] }.each do |class_name, fields|
            output << "## #{class_name}"
            output << "- Extension: #{fields.first['extension']}" if fields.first['extension']
            output << "- File: #{fields.first['file_path']}" if fields.first['file_path']
            output << "- Injected fields:"

            fields.each do |field|
              output << "  - #{field['field_name']} (#{field['annotations']})"
            end

            output << ""
          end

          output.join("\n")
        end

        def error_response(message)
          MCP::Tool::Response.new([{
            type: 'text',
            text: "Error: #{message}"
          }])
        end
      end
    end
  end
end
