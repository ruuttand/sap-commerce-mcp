# frozen_string_literal: true

require 'tree_sitter'
require 'json'
require_relative 'tree_sitter/grammar_loader'

module SapCommerceMcp
  module Parser
    class TreeSitterJavaParser
      # Enhanced tree-sitter Java parser with:
      # - Generic type extraction
      # - Inner class support
      # - Complex annotation parsing
      # - Full method/field extraction

      def initialize
        @language = TreeSitter::GrammarLoader.java_grammar
        @parser = ::TreeSitter::Parser.new
        @parser.language = @language
      end

      def parse_file(file_path)
        @content = File.read(file_path)
        @file_path = file_path
        tree = @parser.parse_string(nil, @content)
        root_node = tree.root_node

        package = extract_package(root_node)
        imports = extract_imports(root_node)

        # Extract main class and all inner classes
        all_classes = extract_all_classes(root_node, package)

        # Return first (main) class info for compatibility
        main_class = all_classes.first

        result = {
          package: package,
          imports: imports,
          class_info: main_class ? main_class[:class_info] : nil,
          methods: main_class ? main_class[:methods] : [],
          fields: main_class ? main_class[:fields] : [],
          annotations: main_class ? main_class[:annotations] : [],
          constructor_params: main_class ? main_class[:constructor_params] : []
        }

        # Add inner classes if present
        result[:inner_classes] = all_classes[1..-1] if all_classes.length > 1

        result
      rescue => e
        warn "Error parsing #{file_path}: #{e.message}"
        warn e.backtrace.first(5).join("\n")
        nil
      end

      private

      # Helper to extract text from a node using byte offsets
      def node_text(node)
        return nil unless node
        @content[node.start_byte...node.end_byte]
      end

      def extract_package(root_node)
        package_node = root_node.find { |child| child.type == :package_declaration }
        return nil unless package_node

        scoped_id = package_node.find { |child| child.type == :scoped_identifier }
        node_text(scoped_id)
      end

      def extract_imports(root_node)
        imports = []

        root_node.each do |child|
          next unless child.type == :import_declaration

          child.each do |import_child|
            if import_child.type == :scoped_identifier
              imports << node_text(import_child)
            elsif import_child.type == :asterisk
              scoped_id = child.find { |c| c.type == :scoped_identifier }
              imports << "#{node_text(scoped_id)}.*" if scoped_id
              break
            end
          end
        end

        imports.uniq
      end

      # Extract all classes (main class + inner classes)
      def extract_all_classes(root_node, package)
        classes = []

        root_node.each do |child|
          if [:class_declaration, :interface_declaration, :enum_declaration, :annotation_type_declaration].include?(child.type)
            classes.concat(extract_class_recursive(child, package, nil))
          end
        end

        classes
      end

      # Recursively extract class and all its inner classes
      def extract_class_recursive(node, package, parent_class_name)
        classes = []

        # Extract this class
        class_data = extract_full_class(node, package, parent_class_name)
        classes << class_data if class_data

        # Find and extract inner classes
        class_body = node.find { |child| child.type == :class_body || child.type == :interface_body || child.type == :enum_body }
        if class_body
          class_body.each do |member|
            if [:class_declaration, :interface_declaration, :enum_declaration, :annotation_type_declaration].include?(member.type)
              inner_classes = extract_class_recursive(member, package, class_data[:class_info][:name])
              classes.concat(inner_classes)
            end
          end
        end

        classes
      end

      # Extract full class data including methods, fields, annotations
      def extract_full_class(node, package, parent_class_name)
        case node.type
        when :class_declaration
          extract_class_declaration(node, package, parent_class_name)
        when :interface_declaration
          extract_interface_declaration(node, package, parent_class_name)
        when :enum_declaration
          extract_enum_declaration(node, package, parent_class_name)
        when :annotation_type_declaration
          extract_annotation_declaration(node, package, parent_class_name)
        end
      end

      def extract_class_declaration(node, package, parent_class_name)
        modifiers = extract_modifiers(node)
        name = extract_name(node)
        generic_sig = extract_type_parameters(node)
        extends = extract_superclass(node)
        implements = extract_super_interfaces(node)
        is_abstract = modifiers.include?('abstract')

        class_annotations = extract_class_annotations(node)
        methods = extract_methods_from_body(node)
        fields = extract_fields_from_body(node)

        {
          class_info: {
            name: name,
            type: is_abstract ? 'abstract' : 'class',
            modifiers: modifiers,
            extends: extends,
            implements: implements,
            is_abstract: is_abstract,
            generic_signature: generic_sig,
            parent_class_name: parent_class_name,
            is_inner_class: !parent_class_name.nil?
          },
          methods: methods,
          fields: fields,
          annotations: class_annotations,
          constructor_params: [] # TODO: Phase 1 extension
        }
      end

      def extract_interface_declaration(node, package, parent_class_name)
        modifiers = extract_modifiers(node)
        name = extract_name(node)
        generic_sig = extract_type_parameters(node)
        extends_list = extract_extends_interfaces(node)

        class_annotations = extract_class_annotations(node)
        methods = extract_methods_from_body(node)
        fields = extract_fields_from_body(node)

        {
          class_info: {
            name: name,
            type: 'interface',
            modifiers: modifiers,
            extends: extends_list.first,
            implements: [],
            is_abstract: false,
            generic_signature: generic_sig,
            parent_class_name: parent_class_name,
            is_inner_class: !parent_class_name.nil?
          },
          methods: methods,
          fields: fields,
          annotations: class_annotations,
          constructor_params: []
        }
      end

      def extract_enum_declaration(node, package, parent_class_name)
        modifiers = extract_modifiers(node)
        name = extract_name(node)
        implements = extract_super_interfaces(node)

        class_annotations = extract_class_annotations(node)
        fields = extract_fields_from_body(node)

        {
          class_info: {
            name: name,
            type: 'enum',
            modifiers: modifiers,
            extends: nil,
            implements: implements,
            is_abstract: false,
            generic_signature: nil,
            parent_class_name: parent_class_name,
            is_inner_class: !parent_class_name.nil?
          },
          methods: [],
          fields: fields,
          annotations: class_annotations,
          constructor_params: []
        }
      end

      def extract_annotation_declaration(node, package, parent_class_name)
        modifiers = extract_modifiers(node)
        name = extract_name(node)

        {
          class_info: {
            name: name,
            type: 'annotation',
            modifiers: modifiers,
            extends: nil,
            implements: [],
            is_abstract: false,
            generic_signature: nil,
            parent_class_name: parent_class_name,
            is_inner_class: !parent_class_name.nil?
          },
          methods: [],
          fields: [],
          annotations: [],
          constructor_params: []
        }
      end

      # Extract generic type parameters like <T extends Model>
      def extract_type_parameters(node)
        type_params_node = node.find { |child| child.type == :type_parameters }
        return nil unless type_params_node

        node_text(type_params_node)
      end

      # Extract methods from class body
      def extract_methods_from_body(node)
        methods = []
        body = node.find { |child| [:class_body, :interface_body].include?(child.type) }
        return methods unless body

        body.each do |member|
          next unless member.type == :method_declaration

          method = extract_method(member)
          methods << method if method
        end

        methods
      end

      def extract_method(node)
        modifiers = extract_modifiers(node)
        name = extract_name(node)
        return nil unless name

        generic_sig = extract_type_parameters(node)
        return_type = extract_method_return_type(node)
        parameters = extract_method_parameters(node)
        annotations = extract_member_annotations(node)

        {
          name: name,
          modifiers: modifiers,
          return_type: return_type,
          generic_signature: generic_sig,
          parameters: parameters,
          signature: build_method_signature(name, parameters, return_type),
          annotations: annotations,
          is_constructor: false
        }
      end

      def extract_method_return_type(node)
        # Find type or void_type node (return type comes before method name)
        # For generic methods, return type can be a type_identifier (like 'R')
        return_type_node = nil

        node.each do |child|
          if [:type, :void_type, :generic_type, :type_identifier].include?(child.type)
            # Skip type_parameters node
            next if child.type == :type_parameters
            return_type_node = child
            break
          end
        end

        return 'void' if return_type_node&.type == :void_type
        node_text(return_type_node) if return_type_node
      end

      def extract_method_parameters(node)
        params = []
        formal_params = node.find { |child| child.type == :formal_parameters }
        return params unless formal_params

        formal_params.each do |param|
          next unless param.type == :formal_parameter

          param_type = nil
          param_name = nil

          param.each do |child|
            case child.type
            when :type, :generic_type
              param_type = node_text(child)
            when :identifier
              param_name = node_text(child)
            end
          end

          params << { type: param_type, name: param_name } if param_type && param_name
        end

        params
      end

      def build_method_signature(name, parameters, return_type)
        param_types = parameters.map { |p| p[:type] }.join(', ')
        "#{return_type} #{name}(#{param_types})"
      end

      # Extract fields from class body
      def extract_fields_from_body(node)
        fields = []
        body = node.find { |child| [:class_body, :interface_body, :enum_body].include?(child.type) }
        return fields unless body

        body.each do |member|
          next unless member.type == :field_declaration

          extracted_fields = extract_field(member)
          fields.concat(extracted_fields)
        end

        fields
      end

      def extract_field(node)
        fields = []
        modifiers = extract_modifiers(node)
        annotations = extract_member_annotations(node)

        # Universal type extractor: Find the first child that represents a type.
        # In tree-sitter Java grammar, field declarations have this structure:
        #   field_declaration: modifiers + TYPE + variable_declarator + ;
        # The type is always the first non-modifiers child, so we find the first
        # child that looks like a type (not modifiers, not variable_declarator, not punctuation)
        type_node = find_type_node(node)
        field_type = node_text(type_node) if type_node

        # If we still don't have a type, skip this field with a warning
        unless field_type
          warn "Could not extract type for field in #{@file_path} at line #{node.start_point.row + 1}"
          return fields
        end

        # Check if type is generic
        generic_type = type_node&.type == :generic_type ? field_type : nil

        # Find all variable declarators (can have multiple fields in one declaration)
        node.each do |child|
          if child.type == :variable_declarator
            field_name = nil
            child.each do |vd_child|
              if vd_child.type == :identifier
                field_name = node_text(vd_child)
                break
              end
            end

            if field_name
              fields << {
                name: field_name,
                type: field_type,
                generic_type: generic_type,
                modifiers: modifiers,
                annotations: annotations
              }
            end
          end
        end

        fields
      end

      # Universal type node finder - works for any Java type without enumerating all possibilities
      # Finds the type node by position: it's the first child that's not modifiers, not punctuation
      def find_type_node(declaration_node)
        declaration_node.each do |child|
          # Skip modifiers and punctuation
          next if child.type == :modifiers
          next if child.type == :'(' || child.type == :')' || child.type == :';' || child.type == :','

          # Skip variable_declarator (comes after type)
          next if child.type == :variable_declarator

          # This should be the type node - it comes after modifiers and before declarators
          # Type nodes include: type_identifier, generic_type, array_type, primitive types, etc.
          return child if looks_like_type_node?(child)
        end

        nil
      end

      # Check if a node represents a type (without enumerating all type node kinds)
      def looks_like_type_node?(node)
        # Type-related node names in tree-sitter Java grammar typically:
        # - End with "_type" (array_type, generic_type, integral_type, floating_point_type, boolean_type, void_type)
        # - Include "type_identifier" (type_identifier, scoped_type_identifier)
        # - Are "type" wrapper node
        node_name = node.type.to_s
        node_name.end_with?('_type') ||
          node_name.include?('type_identifier') ||
          node_name == 'type'
      end

      # Extract class-level annotations
      def extract_class_annotations(node)
        extract_member_annotations(node)
      end

      # Extract annotations for any member (class, method, field)
      def extract_member_annotations(node)
        annotations = []

        # Annotations are inside the modifiers node
        modifiers_node = node.find { |child| child.type == :modifiers }
        return annotations unless modifiers_node

        modifiers_node.each do |child|
          if [:marker_annotation, :annotation].include?(child.type)
            ann = extract_annotation_node(child)
            annotations << ann if ann
          end
        end

        annotations
      end

      def extract_annotation_node(node)
        name = nil
        value = nil
        parameters = {}

        node.each do |child|
          case child.type
          when :identifier, :scoped_identifier
            name = node_text(child)
          when :annotation_argument_list
            parameters = extract_annotation_arguments(child)
          end
        end

        return nil unless name

        {
          name: name,
          value: parameters.empty? ? nil : parameters['value'],
          parameters: parameters.empty? ? nil : parameters.to_json
        }
      end

      def extract_annotation_arguments(node)
        params = {}
        has_pairs = false

        node.each do |child|
          case child.type
          when :element_value_pair
            has_pairs = true
            key = nil
            value = nil
            found_equals = false

            child.each do |pair_child|
              if pair_child.type == :identifier && !found_equals
                key = node_text(pair_child)
              elsif node_text(pair_child) == '='
                found_equals = true
              elsif found_equals
                # This is the value after the equals sign
                value = node_text(pair_child)
                break
              end
            end

            params[key] = value if key && value
          when :'(', :')', :','
            # Skip punctuation
            next
          else
            # Single value without key (defaults to "value")
            if !has_pairs && child.type != :'(' && child.type != :')'
              params['value'] = node_text(child)
            end
          end
        end

        params
      end

      def extract_modifiers(node)
        modifiers = []
        modifiers_node = node.find { |child| child.type == :modifiers }

        if modifiers_node
          modifiers_node.each do |modifier|
            text = node_text(modifier)
            modifiers << text if text&.match?(/^(public|protected|private|abstract|final|static|synchronized|native|strictfp|transient|volatile)$/)
          end
        end

        modifiers
      end

      def extract_name(node)
        name_node = node.find { |child| child.type == :identifier }
        node_text(name_node)
      end

      def extract_superclass(node)
        superclass_node = node.find { |child| child.type == :superclass }
        return nil unless superclass_node

        type_id = superclass_node.find { |child| [:type_identifier, :generic_type].include?(child.type) }
        node_text(type_id)
      end

      def extract_super_interfaces(node)
        interfaces = []

        super_interfaces_node = node.find { |child| child.type == :super_interfaces }
        return interfaces unless super_interfaces_node

        type_list = super_interfaces_node.find { |child| child.type == :type_list }
        return interfaces unless type_list

        type_list.each do |child|
          interfaces << node_text(child) if [:type_identifier, :generic_type].include?(child.type)
        end

        interfaces
      end

      def extract_extends_interfaces(node)
        interfaces = []

        extends_node = node.find { |child| child.type == :extends_interfaces }
        return interfaces unless extends_node

        type_list = extends_node.find { |child| child.type == :type_list }
        return interfaces unless type_list

        type_list.each do |child|
          interfaces << node_text(child) if [:type_identifier, :generic_type].include?(child.type)
        end

        interfaces
      end
    end
  end
end
