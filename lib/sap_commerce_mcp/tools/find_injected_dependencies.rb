# frozen_string_literal: true

require 'json'

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
        - Convention Setter injection (unannotated field + matching setXxx(Type) void setter, wired via Spring XML)

        NOTES:
        - Convention Setter results are suppressed when the annotation filter is used (those fields carry no annotations by definition)
        - Convention Setter results always have annotations=null — wiring is in Spring XML, not in Java source
        - Older SAP Commerce extensions (commerceservices, warehouse, orderprocessing) commonly use Convention Setter style throughout; if a class returns only Convention Setter results, it is fully XML-wired and has no annotation-based injection at all

        USE: "What services does DefaultCheckoutFacade use?", "What injects CheckoutService?", "Show dependencies of X"
        NOT: imports→FindUsages | bean lookup→GetSpringBeans | subclasses→FindImplementations

        RETURNS JSON:
        - Mode 1 (class_name): { class_name, result_count, dependencies: [{dependency_name, dependency_type, injection_type, annotations, class_name, extension}] }
        - Mode 2 (injected_type): { injected_type, result_count, injections: [{class_name, simple_name, extension, file_path, dependency_name, dependency_type, injection_type, annotations}] }
        - injection_type values: "Field", "Constructor", "Method", "Spring XML", "Convention Setter"
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
        # required omitted - all parameters are optional (but at least one of class_name/injected_type must be provided)
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
            formatted_results = {}

            if class_name
              # Find dependencies injected INTO this class
              results = find_dependencies_of_class(db, class_name, annotation, limit)
              formatted_results = {
                class_name: class_name,
                result_count: results.size,
                dependencies: results
              }
            elsif injected_type
              # Find classes that inject this type
              results = find_classes_injecting_type(db, injected_type, annotation, limit)
              formatted_results = {
                injected_type: injected_type,
                result_count: results.size,
                injections: results
              }
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
              text: JSON.pretty_generate(formatted_results)
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
            xml_dependencies: find_xml_dependencies(db, class_name),
            convention_injections: annotation_filter ? [] : find_convention_field_injections(db, class_name)
          }

          # Flatten all results
          all_results = []
          all_results.concat(results[:field_injections].map { |r| r.merge('injection_type' => 'Field') })
          all_results.concat(results[:constructor_injections].map { |r| r.merge('injection_type' => 'Constructor') })
          all_results.concat(results[:method_injections].map { |r| r.merge('injection_type' => 'Method') })
          all_results.concat(results[:xml_dependencies].map { |r| r.merge('injection_type' => 'Spring XML') })
          all_results.concat(results[:convention_injections].map { |r| r.merge('injection_type' => 'Convention Setter') })

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
          convention_results = annotation_filter ? [] : find_convention_setter_injections_of_type(db, injected_type)

          # Flatten all results
          all_results = []
          all_results.concat(field_results.map { |r| r.merge('injection_type' => 'Field') })
          all_results.concat(constructor_results.map { |r| r.merge('injection_type' => 'Constructor') })
          all_results.concat(method_results.map { |r| r.merge('injection_type' => 'Method') })
          all_results.concat(xml_results.map { |r| r.merge('injection_type' => 'Spring XML') })
          all_results.concat(convention_results.map { |r| r.merge('injection_type' => 'Convention Setter') })

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

        def find_convention_field_injections(db, class_name)
          query = <<~SQL
            SELECT
              f.name as dependency_name,
              f.type as dependency_type,
              f.modifiers,
              c.name as class_name,
              c.extension,
              NULL as annotations
            FROM classes c
            INNER JOIN fields f ON c.id = f.class_id
            INNER JOIN methods m ON c.id = m.class_id
            WHERE (c.name LIKE ? OR c.simple_name LIKE ?)
              AND m.name = 'set' || UPPER(SUBSTR(f.name, 1, 1)) || SUBSTR(f.name, 2)
              AND m.return_type = 'void'
              AND (f.modifiers IS NULL OR (f.modifiers NOT LIKE '%static%' AND f.modifiers NOT LIKE '%final%'))
              AND NOT EXISTS (
                SELECT 1 FROM annotations a
                WHERE a.target_type = 'field'
                  AND a.target_id = f.id
                  AND a.annotation_name IN ('Autowired', 'Resource', 'Inject')
              )
            GROUP BY f.id, f.name, f.type, c.name, c.extension
          SQL
          db.execute(query, ["%#{class_name}%", "%#{class_name}%"])
        end

        def find_convention_setter_injections_of_type(db, injected_type)
          query = <<~SQL
            SELECT
              c.name as class_name,
              c.simple_name,
              c.extension,
              c.file_path,
              f.name as dependency_name,
              f.type as dependency_type,
              NULL as annotations
            FROM classes c
            INNER JOIN fields f ON c.id = f.class_id
            INNER JOIN methods m ON c.id = m.class_id
            WHERE (f.type LIKE ? OR f.type = ?)
              AND m.name = 'set' || UPPER(SUBSTR(f.name, 1, 1)) || SUBSTR(f.name, 2)
              AND m.return_type = 'void'
              AND (f.modifiers IS NULL OR (f.modifiers NOT LIKE '%static%' AND f.modifiers NOT LIKE '%final%'))
              AND NOT EXISTS (
                SELECT 1 FROM annotations a
                WHERE a.target_type = 'field'
                  AND a.target_id = f.id
                  AND a.annotation_name IN ('Autowired', 'Resource', 'Inject')
              )
            GROUP BY c.id, f.id, c.name, c.simple_name, c.extension, f.name, f.type
            ORDER BY c.name
          SQL
          db.execute(query, ["%#{injected_type}%", injected_type])
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
