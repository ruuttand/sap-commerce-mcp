# frozen_string_literal: true

module SapCommerceMcp
  module Tools
    class SearchClasses < MCP::Tool
      title 'Search Classes'

      description <<~DESC
        Find classes by NAME/pattern. Fast indexed lookup with wildcards (* ?).

        USE: "Find ProductService", "Show *Facade", "List *Controller in myext", "Find @Service classes"
        NOT: imports→FindUsages | injection→FindInjectedDependencies | subclasses→FindImplementations

        Returns: location, type, extension (not source). Use Read/GetClassSignature for content.
      DESC

      input_schema(
        type: 'object',
        properties: {
          query: {
            type: 'string',
            description: 'Search query (class name, pattern with wildcards like *Service)'
          },
          filters: {
            type: 'object',
            properties: {
              type: {
                type: 'string',
                enum: ['class', 'interface', 'enum', 'abstract'],
                description: 'Filter by class type'
              },
              annotation: {
                type: 'string',
                description: 'Filter by annotation (e.g., @Service, @Controller)'
              },
              extension: {
                type: 'string',
                description: 'Filter by SAP Commerce extension name'
              },
              is_item_model: {
                type: 'boolean',
                description: 'Filter for ItemModel classes only'
              }
            }
          },
          limit: {
            type: 'integer',
            description: 'Maximum number of results to return (default: 50)',
            default: 50
          }
        },
        required: ['query']
      )

      class << self
        def call(query:, filters: {}, limit: 50, server_context:)
          start_time = Time.now

          indexer = server_context[:indexer]
          audit_logger = server_context[:audit_logger]

          # Execute search
          processor = Search::QueryProcessor.new(indexer.db)
          results = processor.search_classes(query, filters, limit)

          # Format results
          formatted_results = {
            query: query,
            filters: filters,
            result_count: results.size,
            results: results.map { |r| Search::ResultFormatter.format_class(r) }
          }

          # Log the operation
          duration_ms = (Time.now - start_time) * 1000
          audit_logger.log_request('search_classes',
                                    { query: query, filters: filters, limit: limit },
                                    formatted_results,
                                    duration_ms)

          # Return response using SDK format
          MCP::Tool::Response.new([{
            type: 'text',
            text: JSON.pretty_generate(formatted_results)
          }])
        rescue => e
          duration_ms = (Time.now - start_time) * 1000 rescue 0
          audit_logger&.log_request('search_classes',
                                    { query: query, filters: filters, limit: limit },
                                    nil,
                                    duration_ms,
                                    error: e)

          MCP::Tool::Response.new([{
            type: 'text',
            text: JSON.generate({ error: e.message, class: e.class.name })
          }])
        end
      end
    end
  end
end
