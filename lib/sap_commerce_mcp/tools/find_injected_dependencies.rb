# frozen_string_literal: true

module SapCommerceMcp
  module Tools
    class FindInjectedDependencies < MCP::Tool
      title 'Find Injected Dependencies'

      description <<~DESC
        Comprehensive dependency analysis: field/constructor/method injection + Spring XML refs. Primary tool for SAP Commerce dependency tracking.

        TWO MODES (use one):
        1. class_name: "What does X depend on?" → finds ALL injected dependencies (fields, constructors, methods, XML)
        2. injected_type: "What depends on X?" → finds ALL classes injecting that type

        TRACKS:
        - Field injection (@Autowired/@Resource/@Inject on fields)
        - Constructor injection (@Autowired on constructor)
        - Method injection (@Autowired on methods)
        - Spring XML property/constructor-arg refs

        USE: "What services does DefaultCheckoutFacade use?", "What injects CheckoutService?", "Show dependencies of X"
        NOT: imports→FindUsages | bean lookup→GetSpringBeans | subclasses→FindImplementations

        Returns: Complete dependency graph with injection type, field/param names, annotations. Filter by annotation: Autowired/Resource/Inject.
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
          results = {
            field_injections: find_field_injections(db, class_name, annotation_filter),
            constructor_injections: find_constructor_injections(db, class_name, annotation_filter),
            method_injections: find_method_injections(db, class_name, annotation_filter),
            xml_dependencies: find_xml_dependencies(db, class_name)
          }

          # Flatten all results
          all_results = []
          all_results.concat(results[:field_injections].map { |r| r.merge('injection_type' => 'Field') })
          all_results.concat(results[:constructor_injections].map { |r| r.merge('injection_type' => 'Constructor') })
          all_results.concat(results[:method_injections].map { |r| r.merge('injection_type' => 'Method') })
          all_results.concat(results[:xml_dependencies].map { |r| r.merge('injection_type' => 'Spring XML') })

          all_results.take(limit)
        end

        def find_field_injections(db, class_name, annotation_filter)
          query = <<~SQL
            SELECT
              f.name as dependency_name,
              f.type as dependency_type,
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
            query += " AND a.annotation_name IN ('Autowired', 'Resource', 'Inject', 'Qualifier')"
            params = ["%#{class_name}%", "%#{class_name}%"]
          end

          query += " GROUP BY f.id, f.name, f.type, c.name, c.extension"

          db.execute(query, params)
        end

        def find_constructor_injections(db, class_name, annotation_filter)
          # Find constructors with @Autowired/@Resource/@Inject
          query = <<~SQL
            SELECT
              cp.param_name as dependency_name,
              cp.param_type as dependency_type,
              c.name as class_name,
              c.extension,
              GROUP_CONCAT(a.annotation_name ||
                CASE WHEN a.annotation_value IS NOT NULL
                     THEN '(' || a.annotation_value || ')'
                     ELSE ''
                END, ', ') as annotations
            FROM classes c
            INNER JOIN constructor_params cp ON c.id = cp.class_id
            LEFT JOIN annotations a ON
              (a.target_type = 'constructor' AND a.target_id = c.id) OR
              (a.target_type = 'constructor_param' AND a.target_id = cp.id)
            WHERE (c.name LIKE ? OR c.simple_name LIKE ?)
          SQL

          if annotation_filter
            query += " AND a.annotation_name = ?"
            params = ["%#{class_name}%", "%#{class_name}%", annotation_filter]
          else
            query += " AND a.annotation_name IN ('Autowired', 'Resource', 'Inject', 'Qualifier')"
            params = ["%#{class_name}%", "%#{class_name}%"]
          end

          query += " GROUP BY cp.id, cp.param_name, cp.param_type, c.name, c.extension"

          db.execute(query, params)
        end

        def find_method_injections(db, class_name, annotation_filter)
          # Find methods with @Autowired/@Resource/@Inject (typically setters)
          # Extract type from method name/parameters
          query = <<~SQL
            SELECT
              m.name as dependency_name,
              m.signature as dependency_type,
              c.name as class_name,
              c.extension,
              GROUP_CONCAT(a.annotation_name, ', ') as annotations
            FROM classes c
            INNER JOIN methods m ON c.id = m.class_id
            LEFT JOIN annotations a ON a.target_type = 'method' AND a.target_id = m.id
            WHERE (c.name LIKE ? OR c.simple_name LIKE ?)
              AND m.name LIKE 'set%'
          SQL

          if annotation_filter
            query += " AND a.annotation_name = ?"
            params = ["%#{class_name}%", "%#{class_name}%", annotation_filter]
          else
            query += " AND a.annotation_name IN ('Autowired', 'Resource', 'Inject')"
            params = ["%#{class_name}%", "%#{class_name}%"]
          end

          query += " GROUP BY m.id, m.name, m.signature, c.name, c.extension"

          db.execute(query, params)
        end

        def find_xml_dependencies(db, class_name)
          # Find Spring XML property/constructor-arg dependencies for this class
          query = <<~SQL
            SELECT
              bd.dependency_name,
              bd.ref_bean_id as dependency_type,
              bd.ref_class,
              bd.dependency_type as xml_dep_type,
              sb.class_name as class_name,
              sb.extension,
              bd.bean_id
            FROM spring_beans sb
            INNER JOIN bean_dependencies bd ON sb.bean_id = bd.bean_id
            WHERE sb.class_name LIKE ? OR sb.class_name LIKE ?
          SQL

          params = ["%#{class_name}%", "%#{class_name}"]

          db.execute(query, params)
        end

        def find_classes_injecting_type(db, injected_type, annotation_filter, limit)
          # Query all injection types
          field_results = find_field_injections_of_type(db, injected_type, annotation_filter)
          constructor_results = find_constructor_injections_of_type(db, injected_type, annotation_filter)
          method_results = find_method_injections_of_type(db, injected_type, annotation_filter)
          xml_results = find_xml_injections_of_type(db, injected_type)

          # Flatten all results
          all_results = []
          all_results.concat(field_results.map { |r| r.merge('injection_type' => 'Field') })
          all_results.concat(constructor_results.map { |r| r.merge('injection_type' => 'Constructor') })
          all_results.concat(method_results.map { |r| r.merge('injection_type' => 'Method') })
          all_results.concat(xml_results.map { |r| r.merge('injection_type' => 'Spring XML') })

          all_results.take(limit)
        end

        def find_field_injections_of_type(db, injected_type, annotation_filter)
          query = <<~SQL
            SELECT
              c.name as class_name,
              c.simple_name,
              c.extension,
              c.file_path,
              f.name as dependency_name,
              f.type as dependency_type,
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

          query += " GROUP BY c.id, f.id, c.name, c.simple_name, c.extension, f.name, f.type ORDER BY c.name"

          db.execute(query, params)
        end

        def find_constructor_injections_of_type(db, injected_type, annotation_filter)
          query = <<~SQL
            SELECT
              c.name as class_name,
              c.simple_name,
              c.extension,
              c.file_path,
              cp.param_name as dependency_name,
              cp.param_type as dependency_type,
              GROUP_CONCAT(a.annotation_name ||
                CASE WHEN a.annotation_value IS NOT NULL
                     THEN '(' || a.annotation_value || ')'
                     ELSE ''
                END, ', ') as annotations
            FROM classes c
            INNER JOIN constructor_params cp ON c.id = cp.class_id
            LEFT JOIN annotations a ON
              (a.target_type = 'constructor' AND a.target_id = c.id) OR
              (a.target_type = 'constructor_param' AND a.target_id = cp.id)
            WHERE (cp.param_type LIKE ? OR cp.param_type = ?)
          SQL

          if annotation_filter
            query += " AND a.annotation_name = ?"
            params = ["%#{injected_type}%", injected_type, annotation_filter]
          else
            query += " AND a.annotation_name IN ('Autowired', 'Resource', 'Inject', 'Qualifier')"
            params = ["%#{injected_type}%", injected_type]
          end

          query += " GROUP BY c.id, cp.id, c.name, c.simple_name, c.extension, cp.param_name, cp.param_type ORDER BY c.name"

          db.execute(query, params)
        end

        def find_method_injections_of_type(db, injected_type, annotation_filter)
          # For method injection, we match against method signature which contains the type
          query = <<~SQL
            SELECT
              c.name as class_name,
              c.simple_name,
              c.extension,
              c.file_path,
              m.name as dependency_name,
              m.signature as dependency_type,
              GROUP_CONCAT(a.annotation_name, ', ') as annotations
            FROM classes c
            INNER JOIN methods m ON c.id = m.class_id
            LEFT JOIN annotations a ON a.target_type = 'method' AND a.target_id = m.id
            WHERE m.signature LIKE ?
              AND m.name LIKE 'set%'
          SQL

          if annotation_filter
            query += " AND a.annotation_name = ?"
            params = ["%#{injected_type}%", annotation_filter]
          else
            query += " AND a.annotation_name IN ('Autowired', 'Resource', 'Inject')"
            params = ["%#{injected_type}%"]
          end

          query += " GROUP BY c.id, m.id, c.name, c.simple_name, c.extension, m.name, m.signature ORDER BY c.name"

          db.execute(query, params)
        end

        def find_xml_injections_of_type(db, injected_type)
          # Find beans that reference this type in their dependencies
          query = <<~SQL
            SELECT
              sb.class_name,
              sb.extension,
              sb.file_path,
              bd.dependency_name,
              bd.ref_bean_id as dependency_type,
              bd.ref_class,
              bd.dependency_type as xml_dep_type,
              bd.bean_id
            FROM spring_beans sb
            INNER JOIN bean_dependencies bd ON sb.bean_id = bd.bean_id
            WHERE bd.ref_class LIKE ?
              OR bd.ref_bean_id IN (
                SELECT bean_id FROM spring_beans
                WHERE class_name LIKE ?
              )
            ORDER BY sb.class_name
          SQL

          params = ["%#{injected_type}%", "%#{injected_type}%"]

          db.execute(query, params)
        end

        def format_dependencies_of_class(class_name, results)
          return "No injected dependencies found for class: #{class_name}" if results.empty?

          output = ["# Injected Dependencies for: #{class_name}", ""]
          output << "Found #{results.size} injected dependency/dependencies:"
          output << ""

          # Group by injection type
          by_type = results.group_by { |r| r['injection_type'] }

          by_type.each do |injection_type, deps|
            output << "## #{injection_type} Injection (#{deps.size})"
            output << ""

            deps.each do |row|
              output << "### #{row['dependency_name']}"
              output << "- Type: #{row['dependency_type']}"
              output << "- Modifiers: #{row['modifiers']}" if row['modifiers'] && !row['modifiers'].empty?
              output << "- Annotations: #{row['annotations']}" if row['annotations']
              output << "- Bean ID: #{row['bean_id']}" if row['bean_id']
              output << "- XML Type: #{row['xml_dep_type']}" if row['xml_dep_type']
              output << "- Extension: #{row['extension']}" if row['extension']
              output << ""
            end
          end

          output.join("\n")
        end

        def format_classes_injecting_type(injected_type, results)
          return "No classes found injecting type: #{injected_type}" if results.empty?

          output = ["# Classes Injecting: #{injected_type}", ""]
          output << "Found #{results.size} injection point(s):"
          output << ""

          # Group by class name, then by injection type
          results.group_by { |r| r['class_name'] }.each do |class_name, injections|
            output << "## #{class_name}"
            output << "- Extension: #{injections.first['extension']}" if injections.first['extension']
            output << "- File: #{injections.first['file_path']}" if injections.first['file_path']
            output << ""

            # Group by injection type within each class
            injections.group_by { |i| i['injection_type'] }.each do |injection_type, deps|
              output << "### #{injection_type} Injection (#{deps.size})"

              deps.each do |dep|
                if dep['xml_dep_type']
                  output << "  - #{dep['dependency_name']} → #{dep['dependency_type']} (#{dep['xml_dep_type']})"
                else
                  output << "  - #{dep['dependency_name']} (#{dep['annotations']})"
                end
              end

              output << ""
            end
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
