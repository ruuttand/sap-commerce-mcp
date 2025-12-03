# frozen_string_literal: true

module SapCommerceMcp
  module Parser
    class JavaParser
      # Simple regex-based Java parser
      # Good enough for extracting class structure without full AST parsing
      
      def parse_file(file_path)
        content = File.read(file_path)

        {
          package: extract_package(content),
          imports: extract_imports(content),
          class_info: extract_class_info(content),
          methods: extract_methods(content),
          fields: extract_fields(content),
          annotations: extract_class_annotations(content)
        }
      rescue => e
        warn "Error parsing #{file_path}: #{e.message}"
        warn e.backtrace.first(5).join("\n")
        nil
      end

      private

      def extract_package(content)
        if (match = content.match(/^\s*package\s+([\w.]+);/m))
          match[1]
        end
      end

      def extract_imports(content)
        imports = []
        content.scan(/^\s*import\s+(?:static\s+)?([\w.*]+);/m) do |match|
          imports << match[0]
        end
        imports
      end

      def extract_class_info(content)
        # Match class/interface/enum declarations
        # Handle generic types: class Foo<T extends Bar>
        pattern = /
          (?:@[\w.]+(?:\([^)]*\))?[\s\n]*)*  # Annotations
          ((?:public|protected|private|abstract|final|static)\s+)*  # Modifiers
          (class|interface|enum|@interface)\s+  # Type
          (\w+)  # Name
          (?:<[^>]+>)?  # Generic params
          (?:\s+extends\s+([\w.<>,\s]+))?  # Extends
          (?:\s+implements\s+([\w.<>,\s]+))?  # Implements
        /mx

        if match = content.match(pattern)
          modifiers = match[1]&.strip&.split(/\s+/) || []
          type = match[2]
          name = match[3]
          extends = match[4]&.strip
          implements = match[5]&.strip&.split(/\s*,\s*/) || []

          {
            name: name,
            type: determine_type(type, modifiers),
            modifiers: modifiers,
            extends: extends,
            implements: implements,
            is_abstract: modifiers.include?('abstract')
          }
        end
      end

      def determine_type(declaration_type, modifiers)
        return 'interface' if declaration_type == 'interface'
        return 'enum' if declaration_type == 'enum'
        return 'annotation' if declaration_type == '@interface'
        return 'abstract' if modifiers.include?('abstract')
        'class'
      end

      def extract_methods(content)
        methods = []
        
        # Match method declarations (not inside strings or comments)
        # This is a simplified version - production would need better comment handling
        pattern = /
          (?:@[\w.]+(?:\([^)]*\))?[\s\n]*)*  # Annotations
          ((?:public|protected|private|static|final|abstract|synchronized|native)\s+)*  # Modifiers
          (?:<[^>]+>\s+)?  # Generic type params
          ([\w.<>\[\],\s]+)\s+  # Return type
          (\w+)\s*  # Method name
          \(([^)]*)\)  # Parameters
          (?:\s*throws\s+([\w.,\s]+))?  # Throws
          \s*[;{]  # Body start or interface method end
        /mx

        content.scan(pattern) do |match|
          next if match[2] == 'class' || match[2] == 'interface' # Skip class declarations

          modifiers = match[0]&.strip&.split(/\s+/) || []
          return_type = match[1]&.strip
          name = match[2]
          params = match[3]&.strip || ''

          # Extract annotations before this method
          last_match = Regexp.last_match
          method_pos = last_match ? last_match.begin(0) : 0
          annotations = extract_method_annotations(content, method_pos)

          methods << {
            name: name,
            modifiers: modifiers,
            return_type: return_type,
            parameters: parse_parameters(params),
            signature: build_signature(name, params, return_type),
            annotations: annotations,
            is_constructor: return_type.nil? || return_type.empty?
          }
        end

        methods
      end

      def extract_method_annotations(content, method_pos)
        # Look backwards for annotations
        before_method = content[0...method_pos]
        annotations = []
        
        # Find annotations in reverse
        before_method.reverse.scan(/@([\w.]+)(?:\([^)]*\))?/).each do |match|
          annotation = match[0]
          break if annotation.nil? || before_method[0...method_pos].match(/\n\s*\n.*@#{annotation}/) # Stop at blank line
          annotations.unshift(annotation)
        end
        
        annotations
      end

      def parse_parameters(params_str)
        return [] if params_str.empty?
        
        params_str.split(',').map do |param|
          parts = param.strip.split(/\s+/)
          {
            type: parts[0..-2].join(' '),
            name: parts[-1]
          }
        end
      end

      def build_signature(name, params, return_type)
        param_types = params.split(',').map do |p|
          p.strip.split(/\s+/)[0..-2].join(' ')
        end.join(', ')
        
        "#{return_type} #{name}(#{param_types})"
      end

      def extract_fields(content)
        fields = []

        # Match field declarations: modifiers + type + name + semicolon
        # This regex matches fields but not methods (no parentheses before semicolon)
        # Pattern: optional modifiers, type, field name, optional initializer, semicolon
        field_pattern = /
          ^\s*                                                    # Start of line
          ((?:(?:public|protected|private|static|final|transient|volatile)\s+)*)  # Modifiers (optional, all of them)
          ([\w.<>\[\]]+)                                          # Type
          \s+                                                     # Whitespace
          (\w+)                                                   # Field name
          (?:\s*=\s*[^;]+)?                                       # Optional initializer
          \s*;                                                    # Semicolon
        /mx

        # Split content into lines for annotation extraction
        lines = content.lines

        # Scan through content to find field declarations
        content.scan(field_pattern) do |match|
          modifiers_str = match[0]
          type = match[1]
          name = match[2]

          # Get the position of this match in the original content
          match_pos = Regexp.last_match.begin(0)

          # Count which line this match is on
          line_idx = content[0...match_pos].count("\n")

          # Look backward through previous lines to find annotations
          annotations = []
          check_line = line_idx - 1

          while check_line >= 0
            line = lines[check_line].strip

            # Check if this line is an annotation
            if line =~ /^@([\w.]+)(?:\(([^)]*)\))?$/
              annotations.unshift({
                name: $1,
                value: $2
              })
              check_line -= 1
            elsif line.empty?
              # Skip blank lines
              check_line -= 1
            else
              # Stop at non-annotation, non-blank line
              break
            end
          end

          fields << {
            name: name,
            type: type,
            modifiers: modifiers_str ? modifiers_str.strip.split(/\s+/) : [],
            annotations: annotations
          }
        end

        fields
      end

      def extract_class_annotations(content)
        annotations = []
        
        # Find annotations before class declaration
        if (match = content.match(/((?:@[\w.]+(?:\([^)]*\))?[\s\n]*)+)(?:public|protected|private|abstract|final|static)*\s*(?:class|interface|enum)/m))
          annotation_block = match[1]
          annotation_block.scan(/@([\w.]+)(?:\(([^)]*)\))?/) do |ann_match|
            annotations << {
              name: ann_match[0],
              value: ann_match[1]
            }
          end
        end
        
        annotations
      end
    end
  end
end
