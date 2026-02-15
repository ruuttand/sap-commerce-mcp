# frozen_string_literal: true

module SapCommerceMcp
  module Tools
    class FindImplementations < MCP::Tool
      title 'Find Implementations'

      description <<~DESC
        Find classes/interfaces that EXTEND or IMPLEMENT the search term (descendants in hierarchy).
        Shows what extends/implements X, NOT what X extends (use GetClassSignature for parents).

        Use this when:
        - Finding interface implementations: "What implements CheckoutFacade?", "Classes that implement KalmarService"
        - Finding subclasses: "Subclasses of AbstractService", "What extends ProductModel?"
        - Understanding inheritance: "Find all implementations of this interface"
        - Impact analysis: "What classes inherit from this base class?"

        Examples:
        - "What implements CheckoutFacade?" → class_or_interface: "CheckoutFacade"
        - "Find subclasses of AbstractService" → class_or_interface: "AbstractService"
        - "Show implementations of KalmarCheckoutFacade" → class_or_interface: "KalmarCheckoutFacade"
        - "What extends DefaultCommerceCartService?" → class_or_interface: "DefaultCommerceCartService"

        Don't use this for:
        - Finding what a class extends/implements (use GetClassSignature instead)
        - Finding classes by name (use SearchClasses instead)
        - Finding which classes import a class (use FindUsages instead)
        - Finding dependency injection (use FindInjectedDependencies instead)

        Returns classes AND interfaces with 'relationship' field indicating type:
        - 'extends': Result extends the search term (class→class or interface→interface)
        - 'implements': Result implements the search term (class→interface)
      DESC

      input_schema(
        type: 'object',
        properties: {
          class_or_interface: {
            type: 'string',
            description: 'Name of the interface or class (simple name or fully qualified) to find descendants of (what extends/implements it)'
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
            search_term: class_or_interface,
            result_count: results.size,
            results: results.map do |r|
              Search::ResultFormatter.format_class(r[:class_data]).merge(
                relationship: r[:relationship]
              )
            end
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
