# frozen_string_literal: true

module SapCommerceMcp
  module Tools
    class GetClassSignature < MCP::Tool
      title 'Get Class Signature'

      description <<~DESC
        Get class API overview: methods, fields, annotations, parent class, and interfaces WITHOUT reading full source.
        Shows what THIS class extends/implements (ancestors), not what extends/implements it (descendants).

        Use this when:
        - Need to see class structure/API: "Show ProductService methods", "What's in DefaultCheckoutFacade?"
        - Finding what a class extends: "What does KalmarCheckoutFacade extend?"
        - Finding what a class implements: "What interfaces does DefaultCartService implement?"
        - Quick method signature lookup without reading entire file

        Examples:
        - "Show methods in ProductService" → class_name: "ProductService"
        - "What does DefaultKalmarCheckoutFacade extend?" → class_name: "DefaultKalmarCheckoutFacade"
        - "API of CartFacade including parent methods" → class_name: "CartFacade", include_inherited: true
        - "What interfaces does LoginController implement?" → class_name: "LoginController"

        Don't use this for:
        - Finding what implements/extends this class (use FindImplementations instead)
        - Reading method implementations/code (use Read tool instead)
        - Finding classes by name pattern (use SearchClasses instead)

        Accepts simple names (e.g., "ProductModel") or fully qualified names. Returns error with candidates if ambiguous.
        Set include_inherited=true to recursively fetch parent class methods (up to 5 levels).

        RETURNS JSON: { class: {...class_info}, methods: [{name, signature, return_type, annotations}], fields: [{name, type, annotations}], annotations: [{annotation_name, annotation_value}] }
      DESC

      input_schema(
        type: 'object',
        properties: {
          class_name: {
            type: 'string',
            description: 'Class/interface name - accepts simple name (e.g., ProductModel) or fully qualified name. Returns error with candidates if ambiguous.'
          },
          include_inherited: {
            type: 'boolean',
            description: 'Include methods from parent classes recursively (follows parent_class chain up to 5 levels)',
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
          elsif signature.is_a?(Hash) && signature[:error]
            # Handle error responses (e.g., ambiguous class names)
            result = signature
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
