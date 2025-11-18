# frozen_string_literal: true

module SapCommerceMcp
  module Tools
    class GetClassSignature < MCP::Tool
      title 'Get Class Signature'
      description 'Get method signatures and structure of a specific class without loading the full file'

      input_schema(
        type: 'object',
        properties: {
          class_name: {
            type: 'string',
            description: 'Fully qualified class name (e.g., de.hybris.platform.core.model.product.ProductModel)'
          },
          include_inherited: {
            type: 'boolean',
            description: 'Include methods from parent classes',
            default: false
          }
        },
        required: ['class_name']
      )

      class << self
        def call(class_name:, include_inherited: false, server_context:)
          start_time = Time.now

          indexer = server_context[:indexer]
          audit_logger = server_context[:audit_logger]

          processor = Search::QueryProcessor.new(indexer.db)
          signature = processor.get_class_signature(class_name, include_inherited)

          if signature.nil?
            result = { error: "Class not found: #{class_name}" }
          else
            result = Search::ResultFormatter.format_signature(signature)
          end

          duration_ms = (Time.now - start_time) * 1000
          audit_logger.log_request('get_class_signature',
                                    { class_name: class_name, include_inherited: include_inherited },
                                    result,
                                    duration_ms)

          MCP::Tool::Response.new([{
            type: 'text',
            text: JSON.pretty_generate(result)
          }])
        rescue => e
          duration_ms = (Time.now - start_time) * 1000 rescue 0
          audit_logger&.log_request('get_class_signature',
                                    { class_name: class_name },
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
