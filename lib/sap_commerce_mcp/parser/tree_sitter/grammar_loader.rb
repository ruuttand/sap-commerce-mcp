# frozen_string_literal: true

module SapCommerceMcp
  module Parser
    module TreeSitter
      class GrammarLoader
        class << self
          def java_grammar
            @java_grammar ||= load_grammar
          end

          private

          def load_grammar
            # Add ~/.sap-commerce-mcp/grammars to TREE_SITTER_PARSERS if not already set
            grammar_dir = File.expand_path('~/.sap-commerce-mcp/grammars')

            original_parsers = ENV['TREE_SITTER_PARSERS']
            if original_parsers
              ENV['TREE_SITTER_PARSERS'] = "#{grammar_dir}:#{original_parsers}" unless original_parsers.include?(grammar_dir)
            else
              ENV['TREE_SITTER_PARSERS'] = grammar_dir
            end

            # Load Java grammar using TreeSitter's search paths
            ::TreeSitter.language('java')
          rescue ::TreeSitter::ParserNotFoundError => e
            raise "Tree-sitter Java grammar not found.\n" \
                  "Please ensure libtree-sitter-java.{dylib,so,dll} is installed at:\n" \
                  "  #{grammar_dir}\n\n" \
                  "To install: Copy the compiled grammar to the above location.\n" \
                  "Download from: https://github.com/tree-sitter/tree-sitter-java/releases\n\n" \
                  "Original error: #{e.message}"
          ensure
            # Don't restore ENV - keep the modified value for subsequent calls
          end
        end
      end
    end
  end
end
