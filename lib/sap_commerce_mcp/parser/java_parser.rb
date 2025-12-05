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
          annotations: extract_class_annotations(content),
          constructor_params: extract_constructor_params(content)
        }
      rescue => e
        warn "Error parsing #{file_path}: #{e.message}"
        warn e.backtrace.first(5).join("\n")
        nil
      end

      private

      # Extract content between balanced parentheses starting at start_pos
      # Returns [content_inside_parens, end_position] or [nil, start_pos] if no match
      def extract_balanced_parentheses(text, start_pos)
        return [nil, start_pos] unless text[start_pos] == '('

        depth = 0
        pos = start_pos
        content_start = nil

        while pos < text.length
          char = text[pos]

          if char == '('
            depth += 1
            content_start = pos + 1 if depth == 1
          elsif char == ')'
            depth -= 1
            if depth == 0
              return [text[content_start...pos], pos]
            end
          end

          pos += 1
        end

        # Unbalanced parentheses
        [nil, start_pos]
      end

      # Extract balanced content from a string, handling both parentheses and angle brackets
      # Used for parsing parameter lists that may contain generic types with nested parens/brackets
      def split_parameters_safely(params_str)
        params = []
        current_param = String.new
        paren_depth = 0
        angle_depth = 0

        params_str.each_char do |char|
          if char == '('
            paren_depth += 1
            current_param << char
          elsif char == ')'
            paren_depth -= 1
            current_param << char
          elsif char == '<'
            angle_depth += 1
            current_param << char
          elsif char == '>'
            angle_depth -= 1
            current_param << char
          elsif char == ',' && paren_depth == 0 && angle_depth == 0
            params << current_param.strip unless current_param.strip.empty?
            current_param = String.new
          else
            current_param << char
          end
        end

        params << current_param.strip unless current_param.strip.empty?
        params
      end

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
        # We need to skip comments and annotations before the class keyword
        # Use word boundary \b to avoid matching "class" inside comments

        # Remove comments first for more accurate matching
        content_without_comments = content.gsub(%r{/\*.*?\*/}m, ' ').gsub(%r{//.*$}, '')

        pattern = /
          \b((?:public|protected|private|abstract|final|static)\s+)*  # Word boundary + Modifiers
          (class|interface|enum|@interface)\s+  # Type
          (\w+)  # Name
          (?:<[^>]+>)?  # Generic params
          (?:\s+extends\s+([\w.<>,\s]+))?  # Extends
          (?:\s+implements\s+([\w.<>,\s]+))?  # Implements
        /mx

        if match = content_without_comments.match(pattern)
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

        # Match method declarations using a two-pass approach
        # Pattern: modifiers return_type method_name(
        # Must have at least one modifier to distinguish from constructors

        method_starts = []

        # Scan original content to keep position mapping intact
        content.scan(/((?:public|protected|private|static|final|abstract|synchronized|native)\s+)+(?:<[^>]+>\s+)?([\w.<>\[\]]+(?:\s*<[^>]+>)?)\s+(\w+)\s*\(/) do
          match_pos = Regexp.last_match.begin(0)
          modifiers = Regexp.last_match[1]
          return_type = Regexp.last_match[2]
          method_name = Regexp.last_match[3]
          param_start = Regexp.last_match.end(0) - 1  # Position of '('

          # Skip class/interface declarations
          next if method_name == 'class' || method_name == 'interface'

          # For constructors, return_type might actually be a modifier
          # Check if return_type looks like a modifier (single word like "public")
          if return_type =~ /^(public|protected|private|static|final|abstract)$/
            # This is likely a constructor where we captured the modifier as return_type
            next  # Skip, constructors handled separately
          end

          # Skip if this looks like it's in a comment
          line_start = content.rindex("\n", match_pos) || 0
          line = content[line_start..match_pos]
          next if line.include?('//') || line.include?('/*')

          method_starts << {
            pos: match_pos,
            param_start: param_start,
            modifiers: modifiers,
            return_type: return_type,
            name: method_name
          }
        end

        # Second pass: extract parameters using balanced parenthesis matching
        method_starts.each do |method_info|
          params_content, close_paren_pos = extract_balanced_parentheses(content, method_info[:param_start])
          next unless params_content && close_paren_pos

          # Check if this is followed by { or ; (method body or declaration)
          after_params = content[(close_paren_pos + 1)..(close_paren_pos + 100)]
          next unless after_params&.match?(/^\s*(?:throws\s+[\w.,\s]+)?\s*[;{]/)

          modifiers = method_info[:modifiers]&.strip&.split(/\s+/) || []
          return_type = method_info[:return_type]&.strip
          name = method_info[:name]
          params = params_content&.strip || ''

          # Extract annotations before this method
          annotations = extract_method_annotations(content, method_info[:pos])

          methods << {
            name: name,
            modifiers: modifiers,
            return_type: return_type,
            parameters: parse_parameters(params),
            signature: build_signature(name, params, return_type),
            annotations: annotations,
            is_constructor: false
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

        # Use safe splitting that handles nested parentheses and angle brackets
        split_parameters_safely(params_str).map do |param|
          parts = param.strip.split(/\s+/)
          {
            type: parts[0..-2].join(' '),
            name: parts[-1]
          }
        end
      end

      def build_signature(name, params, return_type)
        # Use safe splitting that handles nested parentheses and angle brackets
        param_types = split_parameters_safely(params).map do |p|
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

            # Check if this line starts with an annotation
            if line =~ /^@([\w.]+)/
              annotation_name = $1
              annotation_value = nil

              # Check if there's a parenthesized value
              after_name = line[($~.end(0))..-1]
              if after_name && after_name.strip.start_with?('(')
                # Extract balanced parentheses from this line only
                paren_start = after_name.index('(')
                value, end_pos = extract_balanced_parentheses(after_name, paren_start)

                # Check if the closing paren is found on this line
                if value && after_name[end_pos] == ')' && after_name[(end_pos+1)..-1]&.strip&.empty?
                  annotation_value = value
                else
                  # Multi-line annotation or unclosed parens, skip it
                  break
                end
              end

              annotations.unshift({
                name: annotation_name,
                value: annotation_value
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

        # Find class declaration position
        class_match = content.match(/(?:public|protected|private|abstract|final|static)*\s*(?:class|interface|enum)\s+\w+/)
        return annotations unless class_match

        class_pos = class_match.begin(0)

        # Extract annotations before the class declaration
        annotations = extract_annotations_before_position(content, class_pos)

        annotations
      end

      def extract_constructor_params(content)
        # Extract class name first
        class_info = extract_class_info(content)
        return [] unless class_info

        class_name = class_info[:name]
        constructor_params = []

        # Find constructor declarations using two-pass approach
        # First, find all positions where constructor might start
        constructor_starts = []

        # Pattern: optional annotations + modifiers + class_name + (
        simple_pattern = /((?:public|protected|private)\s+)?#{Regexp.escape(class_name)}\s*\(/

        content.scan(simple_pattern) do
          match_pos = Regexp.last_match.begin(0)
          paren_pos = Regexp.last_match.end(0) - 1

          # Extract annotations before this position
          constructor_annotations = extract_annotations_before_position(content, match_pos)

          constructor_starts << {
            pos: match_pos,
            paren_pos: paren_pos,
            annotations: constructor_annotations
          }
        end

        # Second pass: extract parameters using balanced parenthesis matching
        constructor_starts.each do |constructor_info|
          params_content, _ = extract_balanced_parentheses(content, constructor_info[:paren_pos])
          next unless params_content

          params_str = params_content.strip
          next if params_str.empty?

          params = parse_constructor_parameters(params_str)

          # Store constructor info with its parameters
          constructor_params << {
            has_injection_annotation: constructor_info[:annotations].any? { |a|
              ['Autowired', 'Resource', 'Inject'].include?(a[:name])
            },
            constructor_annotations: constructor_info[:annotations],
            parameters: params
          }
        end

        constructor_params
      end

      # Extract annotations that appear before a given position in the content
      def extract_annotations_before_position(content, position)
        annotations = []

        # Look backward from position to find annotations
        before_content = content[0...position]
        lines = before_content.lines

        # Start from the last line and work backwards
        (lines.length - 1).downto(0) do |i|
          line = lines[i].strip

          # Match annotation pattern
          if line =~ /^@([\w.]+)(?:\((.*)\))?$/
            annotation_name = $1
            annotation_value = $2

            # For annotation values with balanced parentheses, we need to check if complete
            if annotation_value && annotation_value.count('(') != annotation_value.count(')')
              # Multi-line annotation, skip for now
              break
            end

            annotations.unshift({
              name: annotation_name,
              value: annotation_value
            })
          elsif line.empty?
            # Continue through blank lines
            next
          else
            # Stop at non-annotation, non-blank content
            break
          end
        end

        annotations
      end

      def parse_constructor_parameters(params_str)
        # Split by commas, but be careful of:
        # - Generic types like Map<String, String>
        # - Annotations with nested parens like @Qualifier(value = "test()")
        params = []
        current_param = String.new
        angle_bracket_depth = 0
        paren_depth = 0

        params_str.each_char do |char|
          if char == '<'
            angle_bracket_depth += 1
            current_param << char
          elsif char == '>'
            angle_bracket_depth -= 1
            current_param << char
          elsif char == '('
            paren_depth += 1
            current_param << char
          elsif char == ')'
            paren_depth -= 1
            current_param << char
          elsif char == ',' && angle_bracket_depth == 0 && paren_depth == 0
            params << parse_single_parameter(current_param.strip)
            current_param = String.new
          else
            current_param << char
          end
        end

        # Add the last parameter
        params << parse_single_parameter(current_param.strip) unless current_param.strip.empty?

        params
      end

      def parse_single_parameter(param_str)
        # Match: (annotations) type name
        # Example: @Qualifier("foo") final ProductService productService
        # Example with nested parens: @Qualifier(value = "test()") ProductService productService

        annotations = []

        # Extract annotations with balanced parentheses
        # Find all @ symbols and extract annotation name + balanced parens
        clean_str = param_str.dup
        pos = 0

        while pos < clean_str.length
          if clean_str[pos] == '@'
            # Extract annotation name
            name_match = clean_str[pos..-1].match(/^@([\w.]+)/)
            if name_match
              annotation_name = name_match[1]
              after_name_pos = pos + name_match.end(0)

              # Check if there's a parenthesized value
              if after_name_pos < clean_str.length && clean_str[after_name_pos] == '('
                value, end_pos = extract_balanced_parentheses(clean_str, after_name_pos)

                annotations << {
                  name: annotation_name,
                  value: value
                }

                # Remove the annotation from the string
                clean_str[pos..end_pos] = ' ' * (end_pos - pos + 1)
                pos = end_pos + 1
              else
                # Annotation without parentheses
                annotations << {
                  name: annotation_name,
                  value: nil
                }

                # Remove the annotation from the string
                clean_str[pos...(pos + name_match.end(0))] = ' ' * name_match.end(0)
                pos += name_match.end(0)
              end
            else
              pos += 1
            end
          else
            pos += 1
          end
        end

        # Remove 'final' keyword
        clean_str.gsub!(/\bfinal\s+/, '')

        # Now split by whitespace to get type and name
        parts = clean_str.strip.split(/\s+/).reject(&:empty?)

        if parts.length >= 2
          {
            type: parts[0..-2].join(' '),  # Everything except last part is type
            name: parts[-1],                # Last part is name
            annotations: annotations
          }
        else
          # Malformed parameter, just use what we have
          {
            type: parts[0] || 'unknown',
            name: 'unknown',
            annotations: annotations
          }
        end
      end
    end
  end
end
