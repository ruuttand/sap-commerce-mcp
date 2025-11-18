# frozen_string_literal: true

module SapCommerceMcp
  module Tools
    class FindImplementations < MCP::Tool
      title 'Find Implementations'
      description 'Find all classes that implement an interface or extend a class'

      input_schema(
        type: 'object',
        properties: {
          class_or_interface: {
            type: 'string',
            description: 'Fully qualified name of interface or class'
          },
          limit: {
            type: 'integer',
            description: 'Maximum number of results (default: 100)',
            default: 100
          }
        },
        required: ['class_or_interface']
      )

      class << self
        def call(class_or_interface:, limit: 100, server_context:)
          start_time = Time.now

          indexer = server_context[:indexer]
          audit_logger = server_context[:audit_logger]

          processor = Search::QueryProcessor.new(indexer.db)
          results = processor.find_implementations(class_or_interface, limit)

          formatted_results = {
            interface: class_or_interface,
            result_count: results.size,
            implementations: results.map { |r| Search::ResultFormatter.format_class(r) }
          }

          duration_ms = (Time.now - start_time) * 1000
          audit_logger.log_request('find_implementations',
                                    { class_or_interface: class_or_interface, limit: limit },
                                    formatted_results,
                                    duration_ms)

          MCP::Tool::Response.new([{
            type: 'text',
            text: JSON.pretty_generate(formatted_results)
          }])
        rescue => e
          duration_ms = (Time.now - start_time) * 1000 rescue 0
          audit_logger&.log_request('find_implementations',
                                    { class_or_interface: class_or_interface },
                                    nil,
                                    duration_ms,
                                    error: e)

          MCP::Tool::Response.new([{
            type: 'text',
            text: JSON.generate({ error: e.message })
          }])
        end
      end
    end
  end
end
