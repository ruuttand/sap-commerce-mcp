# frozen_string_literal: true

require 'tree_sitter'
require_relative 'tree_sitter/grammar_loader'

module SapCommerceMcp
  module Parser
    class TreeSitterJavaParser
      # Tree-sitter based Java parser - POC implementation
      # Provides same interface as JavaParser but uses AST parsing instead of regex
      #
      # POC scope: package, imports, class_info extraction
      # Not yet implemented: methods, fields, annotations, constructor_params

      def initialize
        @language = TreeSitter::GrammarLoader.java_grammar
        @parser = ::TreeSitter::Parser.new
        @parser.language = @language
      end

      def parse_file(file_path)
        @content = File.read(file_path)
        tree = @parser.parse_string(nil, @content)
        root_node = tree.root_node

        {
          package: extract_package(root_node),
          imports: extract_imports(root_node),
          class_info: extract_class_info(root_node),
          methods: [],      # Empty for POC
          fields: [],       # Empty for POC
          annotations: [],  # Empty for POC
          constructor_params: []  # Empty for POC
        }
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
        # Find package declaration (note: type returns symbol)
        package_node = root_node.find { |child| child.type == :package_declaration }
        return nil unless package_node

        # Find the scoped_identifier child
        scoped_id = package_node.find { |child| child.type == :scoped_identifier }
        node_text(scoped_id)
      end

      def extract_imports(root_node)
        imports = []

        root_node.each do |child|
          next unless child.type == :import_declaration

          # Find scoped_identifier or asterisk children
          child.each do |import_child|
            if import_child.type == :scoped_identifier
              imports << node_text(import_child)
            elsif import_child.type == :asterisk
              # Handle wildcard imports like import java.util.*;
              scoped_id = child.find { |c| c.type == :scoped_identifier }
              imports << "#{node_text(scoped_id)}.*" if scoped_id
              break
            end
          end
        end

        imports.uniq
      end

      def extract_class_info(root_node)
        # Look for class, interface, enum, or annotation declarations
        declaration_node = root_node.find do |child|
          [:class_declaration, :interface_declaration, :enum_declaration, :annotation_type_declaration].include?(child.type)
        end

        return nil unless declaration_node

        case declaration_node.type
        when :class_declaration
          extract_class_declaration(declaration_node)
        when :interface_declaration
          extract_interface_declaration(declaration_node)
        when :enum_declaration
          extract_enum_declaration(declaration_node)
        when :annotation_type_declaration
          extract_annotation_declaration(declaration_node)
        end
      end

      def extract_class_declaration(node)
        modifiers = extract_modifiers(node)
        name = extract_name(node)
        extends = extract_superclass(node)
        implements = extract_super_interfaces(node)
        is_abstract = modifiers.include?('abstract')

        {
          name: name,
          type: is_abstract ? 'abstract' : 'class',
          modifiers: modifiers,
          extends: extends,
          implements: implements,
          is_abstract: is_abstract
        }
      end

      def extract_interface_declaration(node)
        modifiers = extract_modifiers(node)
        name = extract_name(node)
        extends_list = extract_extends_interfaces(node)

        {
          name: name,
          type: 'interface',
          modifiers: modifiers,
          extends: extends_list.first,  # Interfaces can extend multiple, but we take first for compatibility
          implements: [],
          is_abstract: false
        }
      end

      def extract_enum_declaration(node)
        modifiers = extract_modifiers(node)
        name = extract_name(node)
        implements = extract_super_interfaces(node)

        {
          name: name,
          type: 'enum',
          modifiers: modifiers,
          extends: nil,
          implements: implements,
          is_abstract: false
        }
      end

      def extract_annotation_declaration(node)
        modifiers = extract_modifiers(node)
        name = extract_name(node)

        {
          name: name,
          type: 'annotation',
          modifiers: modifiers,
          extends: nil,
          implements: [],
          is_abstract: false
        }
      end

      def extract_modifiers(node)
        modifiers = []
        modifiers_node = node.find { |child| child.type == :modifiers }

        if modifiers_node
          modifiers_node.each do |modifier|
            text = node_text(modifier)
            modifiers << text if text&.match?(/^(public|protected|private|abstract|final|static)$/)
          end
        end

        modifiers
      end

      def extract_name(node)
        name_node = node.find { |child| child.type == :identifier }
        node_text(name_node)
      end

      def extract_superclass(node)
        # Find superclass node
        superclass_node = node.find { |child| child.type == :superclass }
        return nil unless superclass_node

        # Extract type_identifier from superclass
        type_id = superclass_node.find { |child| child.type == :type_identifier }
        node_text(type_id)
      end

      def extract_super_interfaces(node)
        interfaces = []

        # Find super_interfaces node
        super_interfaces_node = node.find { |child| child.type == :super_interfaces }
        return interfaces unless super_interfaces_node

        # Find type_list within super_interfaces
        type_list = super_interfaces_node.find { |child| child.type == :type_list }
        return interfaces unless type_list

        # Extract all type_identifiers from the type_list
        type_list.each do |child|
          interfaces << node_text(child) if child.type == :type_identifier
        end

        interfaces
      end

      def extract_extends_interfaces(node)
        interfaces = []

        # Find extends_interfaces node (specific to interface declarations)
        extends_node = node.find { |child| child.type == :extends_interfaces }
        return interfaces unless extends_node

        # Find type_list within extends_interfaces
        type_list = extends_node.find { |child| child.type == :type_list }
        return interfaces unless type_list

        # Extract all type_identifiers from the type_list
        type_list.each do |child|
          interfaces << node_text(child) if child.type == :type_identifier
        end

        interfaces
      end
    end
  end
end
