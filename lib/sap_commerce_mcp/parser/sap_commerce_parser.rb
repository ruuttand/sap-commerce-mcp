# frozen_string_literal: true

require 'nokogiri'
require 'set'

module SapCommerceMcp
  module Parser
    class SapCommerceParser
      def initialize(project_path, use_tree_sitter: false)
        @project_path = project_path
        @use_tree_sitter = use_tree_sitter

        # Choose parser based on flag and availability
        if @use_tree_sitter && defined?(TreeSitterJavaParser)
          @java_parser = TreeSitterJavaParser.new
        else
          @java_parser = JavaParser.new
        end
      end

      def parse_java_file(file_path)
        parsed = @java_parser.parse_file(file_path)
        return nil unless parsed

        # Add SAP Commerce-specific metadata
        parsed[:extension] = detect_extension(file_path)
        parsed[:is_item_model] = item_model?(parsed)
        
        parsed
      end

      def parse_spring_xml(file_path)
        doc = Nokogiri::XML(File.read(file_path))
        beans = []

        # Use local-name() to ignore XML namespaces
        doc.xpath('//*[local-name()="bean"]').each do |bean_node|
          bean_id = bean_node['id']

          # Extract property and constructor-arg dependencies
          dependencies = extract_bean_dependencies(bean_node)

          beans << {
            id: bean_id,
            class: bean_node['class'],
            parent: bean_node['parent'],
            scope: bean_node['scope'],
            abstract: bean_node['abstract'] == 'true',
            dependencies: dependencies
          }
        end

        beans
      rescue => e
        warn "Error parsing Spring XML #{file_path}: #{e.message}"
        []
      end

      def find_extensions
        extensions = []
        seen_paths = Set.new

        # Find all extensioninfo.xml files recursively
        search_roots = [
          File.join(@project_path, 'bin'),
          File.join(@project_path, 'hybris', 'bin')
        ].select { |path| File.directory?(path) }

        search_roots.each do |root|
          # Find all extensioninfo.xml files
          Dir.glob(File.join(root, '**', 'extensioninfo.xml')).each do |info_file|
            extension_path = File.dirname(info_file)

            # Skip if we've already seen this path
            next if seen_paths.include?(extension_path)
            seen_paths << extension_path

            # Verify it has source files or is a valid extension
            if has_extension_structure?(extension_path)
              extensions << {
                name: File.basename(extension_path),
                path: extension_path
              }
            end
          end
        end

        # Always scan platform bootstrap (contains generated ItemModels)
        bootstrap_paths = [
          File.join(@project_path, 'bin', 'platform', 'bootstrap'),
          File.join(@project_path, 'hybris', 'bin', 'platform', 'bootstrap')
        ]

        bootstrap_paths.each do |bootstrap_path|
          if File.directory?(bootstrap_path) && !seen_paths.include?(bootstrap_path)
            seen_paths << bootstrap_path
            extensions << {
              name: 'platform_bootstrap',
              path: bootstrap_path
            }
          end
        end

        # If no extensions found via extensioninfo.xml, fall back to directory patterns
        if extensions.empty?
          search_paths = [
            File.join(@project_path, 'bin', 'custom', '*'),
            File.join(@project_path, 'bin', 'custom', '*', '*'),
            File.join(@project_path, 'bin', 'ext-*', '*'),
            File.join(@project_path, 'bin', 'platform', 'ext', '*'),
            File.join(@project_path, 'bin', 'modules', '*', '*'),
            File.join(@project_path, 'hybris', 'bin', 'custom', '*'),
            File.join(@project_path, 'hybris', 'bin', 'custom', '*', '*'),
            File.join(@project_path, 'hybris', 'bin', 'ext-*', '*'),
            File.join(@project_path, 'hybris', 'bin', 'platform', 'ext', '*'),
            File.join(@project_path, 'hybris', 'bin', 'modules', '*', '*')
          ]

          search_paths.each do |pattern|
            Dir.glob(pattern).each do |path|
              next if seen_paths.include?(path)

              if File.directory?(path) && has_extension_structure?(path)
                seen_paths << path
                extensions << {
                  name: File.basename(path),
                  path: path
                }
              end
            end
          end
        end

        extensions
      end

      def find_java_files(extension_path)
        java_files = []
        
        ['src', 'web/src', 'testsrc', 'gensrc'].each do |src_dir|
          src_path = File.join(extension_path, src_dir)
          next unless File.directory?(src_path)
          
          Dir.glob(File.join(src_path, '**', '*.java')).each do |file|
            java_files << file
          end
        end

        java_files
      end

      def find_spring_xml_files(extension_path)
        resources_path = File.join(extension_path, 'resources')
        return [] unless File.directory?(resources_path)

        Dir.glob(File.join(resources_path, '**', '*-spring.xml'))
      end

      private

      def extract_bean_dependencies(bean_node)
        dependencies = []

        # Extract <property name="..." ref="..."/>
        bean_node.xpath('.//*[local-name()="property"]').each do |prop|
          ref = prop['ref']
          value_attr = prop['value']

          # Only track ref-based dependencies (not value-based)
          if ref
            dependencies << {
              type: 'property',
              name: prop['name'],
              ref_bean_id: ref,
              ref_class: nil
            }
          end
        end

        # Extract <constructor-arg ref="..." /> or <constructor-arg><ref bean="..."/></constructor-arg>
        bean_node.xpath('.//*[local-name()="constructor-arg"]').each_with_index do |arg, index|
          ref = arg['ref']
          name = arg['name']
          type = arg['type']

          # Check for nested <ref bean="..."/> element
          ref_element = arg.at_xpath('.//*[local-name()="ref"]')
          ref ||= ref_element['bean'] if ref_element

          if ref
            dependencies << {
              type: 'constructor-arg',
              name: name || index.to_s,  # Use name if available, otherwise index
              ref_bean_id: ref,
              ref_class: type
            }
          end
        end

        dependencies
      end

      def detect_extension(file_path)
        # Extract extension name from path
        # Typical paths:
        # .../bin/custom/myextension/src/...
        # .../bin/ext-commerce/commerceservices/src/...
        
        if match = file_path.match(/\/(?:bin\/(?:custom|ext-[^\/]+)|hybris\/bin\/(?:custom|ext-[^\/]+))\/([^\/]+)\//)
          match[1]
        end
      end

      def item_model?(parsed)
        return false unless parsed[:class_info]
        
        class_name = parsed[:class_info][:name]
        parent_class = parsed[:class_info][:extends]
        
        # Check if it's an ItemModel
        class_name&.end_with?('Model') && 
          (parent_class&.include?('ItemModel') || parent_class == 'ItemModel')
      end

      def has_extension_structure?(path)
        # Check for typical SAP Commerce extension structure
        File.exist?(File.join(path, 'extensioninfo.xml')) ||
          File.directory?(File.join(path, 'src')) ||
          File.directory?(File.join(path, 'resources'))
      end
    end
  end
end
