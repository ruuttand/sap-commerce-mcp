# frozen_string_literal: true

module SapCommerceMcp
  module Tools
    # Find Usages Tool
    class FindUsages < MCP::Tool
      title 'Find Usages'

      description <<~DESC
        Find classes that IMPORT a specific class (compile-time dependency). Searches imports table.

        Accepts both fully qualified names (e.g., de.hybris.platform.core.model.product.ProductModel)
        and simple names (e.g., ProductModel). Simple names may match multiple imports if ambiguous.

        USE: "What imports ProductService?", "Find compile-time references to CheckoutFacade"
        NOT: runtime injection→FindInjectedDependencies (better for SAP Commerce) | subclasses→FindImplementations

        RETURNS JSON: { class, result_count, usages: [{name, file_path, extension}] }
      DESC

      input_schema(
        type: 'object',
        properties: {
          class_name: {
            type: 'string',
            description: 'Class name (accepts both fully qualified or simple names like "ProductModel")'
          },
          limit: {
            type: 'integer',
            description: 'Maximum number of results (default: 100)',
            default: 100
          }
        },
        required: ['class_name']
      )

      class << self
        def call(class_name:, limit: 100, server_context:)
          start_time = Time.now

          indexer = server_context[:indexer]
          audit_logger = server_context[:audit_logger]

          processor = Search::QueryProcessor.new(indexer.db)
          results = processor.find_usages(class_name, limit)

          formatted_results = {
            class: class_name,
            result_count: results.size,
            usages: results
          }

          duration_ms = (Time.now - start_time) * 1000
          audit_logger.log_request('find_usages',
                                    { class_name: class_name, limit: limit },
                                    formatted_results,
                                    duration_ms)

          MCP::Tool::Response.new([{
            type: 'text',
            text: JSON.pretty_generate(formatted_results)
          }])
        rescue => e
          duration_ms = (Time.now - start_time) * 1000 rescue 0
          audit_logger&.log_request('find_usages', { class_name: class_name }, nil, duration_ms, error: e)
          MCP::Tool::Response.new([{ type: 'text', text: JSON.generate({ error: e.message }) }])
        end
      end
    end

    # Search Annotations Tool
    class SearchAnnotations < MCP::Tool
      title 'Search Annotations'

      description <<~DESC
        Find classes/methods/fields with specific annotation (@Service, @Controller, @Autowired, etc).

        USE: "Find @Controller classes", "Show @Autowired methods", "List @Service annotated"
        Common: @Service, @Controller, @Component, @Repository, @Autowired, @Resource

        RETURNS JSON: { annotation, target_type, result_count, results: { classes: [...], methods: [...], fields: [...] } } or single array if target_type specified
      DESC

      input_schema(
        type: 'object',
        properties: {
          annotation_name: {
            type: 'string',
            description: 'Annotation name (with or without @, e.g., Controller or @Controller)'
          },
          target_type: {
            type: 'string',
            enum: ['class', 'method', 'field', 'all'],
            description: 'Where to look for the annotation',
            default: 'all'
          },
          limit: {
            type: 'integer',
            description: 'Maximum number of results (default: 100)',
            default: 100
          }
        },
        required: ['annotation_name']
      )

      class << self
        def call(annotation_name:, target_type: 'all', limit: 100, server_context:)
          start_time = Time.now

          indexer = server_context[:indexer]
          audit_logger = server_context[:audit_logger]

          annotation_name = annotation_name.sub(/^@/, '')
          processor = Search::QueryProcessor.new(indexer.db)
          results = processor.search_annotations(annotation_name, target_type, limit)

          formatted_results = {
            annotation: "@#{annotation_name}",
            target_type: target_type,
            result_count: results.is_a?(Hash) ?
              (results[:classes]&.size || 0) + (results[:methods]&.size || 0) :
              results.size,
            results: results
          }

          duration_ms = (Time.now - start_time) * 1000
          audit_logger.log_request('search_annotations',
                                    { annotation_name: annotation_name, target_type: target_type, limit: limit },
                                    formatted_results,
                                    duration_ms)

          MCP::Tool::Response.new([{
            type: 'text',
            text: JSON.pretty_generate(formatted_results)
          }])
        rescue => e
          duration_ms = (Time.now - start_time) * 1000 rescue 0
          audit_logger&.log_request('search_annotations',
                                    { annotation_name: annotation_name },
                                    nil,
                                    duration_ms,
                                    error: e)
          MCP::Tool::Response.new([{ type: 'text', text: JSON.generate({ error: e.message }) }])
        end
      end
    end

    # Get Spring Beans Tool
    class GetSpringBeans < MCP::Tool
      title 'Get Spring Beans'

      description <<~DESC
        Search Spring XML bean definitions (*-spring.xml files). Pattern matching on bean IDs.

        USE: "Find bean checkoutService", "Show *Facade beans", "Beans in commerceservices"
        NOT: field injection→FindInjectedDependencies | classes→SearchClasses

        RETURNS JSON: { pattern, extension?, result_count, beans: [{bean_id, class_name, parent_bean?, scope?, extension, file_path}] }
      DESC

      input_schema(
        type: 'object',
        properties: {
          bean_id_pattern: {
            type: 'string',
            description: 'Bean ID pattern (supports wildcards like *Service)'
          },
          extension: {
            type: 'string',
            description: 'Filter by extension name'
          },
          limit: {
            type: 'integer',
            description: 'Maximum number of results (default: 50)',
            default: 50
          }
        },
        required: ['bean_id_pattern']
      )

      class << self
        def call(bean_id_pattern:, extension: nil, limit: 50, server_context:)
          start_time = Time.now

          indexer = server_context[:indexer]
          audit_logger = server_context[:audit_logger]

          processor = Search::QueryProcessor.new(indexer.db)
          results = processor.search_spring_beans(bean_id_pattern, extension, limit)

          formatted_results = {
            pattern: bean_id_pattern,
            extension: extension,
            result_count: results.size,
            beans: results
          }

          duration_ms = (Time.now - start_time) * 1000
          audit_logger.log_request('get_spring_beans',
                                    { bean_id_pattern: bean_id_pattern, extension: extension, limit: limit },
                                    formatted_results,
                                    duration_ms)

          MCP::Tool::Response.new([{
            type: 'text',
            text: JSON.pretty_generate(formatted_results)
          }])
        rescue => e
          duration_ms = (Time.now - start_time) * 1000 rescue 0
          audit_logger&.log_request('get_spring_beans',
                                    { bean_id_pattern: bean_id_pattern },
                                    nil,
                                    duration_ms,
                                    error: e)
          MCP::Tool::Response.new([{ type: 'text', text: JSON.generate({ error: e.message }) }])
        end
      end
    end

    # Rebuild Index Tool
    class RebuildIndex < MCP::Tool
      title 'Rebuild Index'
      description 'Force rebuild of code index. Use after major codebase changes. Set force=true to override existing index.'

      input_schema(
        type: 'object',
        properties: {
          force: {
            type: 'boolean',
            description: 'Force full reindex even if index exists',
            default: false
          }
        }
        # required omitted - all parameters are optional
      )

      class << self
        def call(force: false, server_context:)
          start_time = Time.now

          indexer = server_context[:indexer]
          audit_logger = server_context[:audit_logger]

          if !force && indexer.index_exists?
            last_indexed = indexer.last_indexed_time
            result = {
              status: 'skipped',
              message: 'Index already exists. Use force=true to rebuild.',
              last_indexed: last_indexed&.strftime('%Y-%m-%d %H:%M:%S')
            }
          else
            stats = indexer.build_index
            audit_logger.log_indexing(stats)
            result = {
              status: 'completed',
              stats: stats
            }
          end

          duration_ms = (Time.now - start_time) * 1000
          audit_logger.log_request('rebuild_index', { force: force }, result, duration_ms)

          MCP::Tool::Response.new([{
            type: 'text',
            text: JSON.pretty_generate(result)
          }])
        rescue => e
          duration_ms = (Time.now - start_time) * 1000 rescue 0
          audit_logger&.log_request('rebuild_index', { force: force }, nil, duration_ms, error: e)
          MCP::Tool::Response.new([{ type: 'text', text: JSON.generate({ error: e.message }) }])
        end
      end
    end

    # Get Index Stats Tool
    class GetIndexStats < MCP::Tool
      title 'Get Index Statistics'
      description 'Show index statistics: classes, methods, fields, annotations, beans count, last indexed time, size.'

      input_schema(
        type: 'object',
        properties: {
          _unused: {
            type: 'boolean',
            description: 'Unused parameter for schema compatibility',
            default: false
          }
        }
        # required omitted - all parameters are optional
      )

      class << self
        def call(_unused: false, server_context:)
          start_time = Time.now

          indexer = server_context[:indexer]
          audit_logger = server_context[:audit_logger]

          stats = indexer.get_stats

          duration_ms = (Time.now - start_time) * 1000
          audit_logger.log_request('get_index_stats', {}, stats, duration_ms)

          MCP::Tool::Response.new([{
            type: 'text',
            text: JSON.pretty_generate(stats)
          }])
        rescue => e
          duration_ms = (Time.now - start_time) * 1000 rescue 0
          audit_logger&.log_request('get_index_stats', {}, nil, duration_ms, error: e)
          MCP::Tool::Response.new([{ type: 'text', text: JSON.generate({ error: e.message }) }])
        end
      end
    end
  end
end
