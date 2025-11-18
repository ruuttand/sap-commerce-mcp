# frozen_string_literal: true

module SapCommerceMcp
  module Search
    class ResultFormatter
      def self.format_class(class_data)
        {
          name: class_data['name'],
          simple_name: class_data['simple_name'],
          type: class_data['type'],
          extension: class_data['extension'],
          file_path: class_data['file_path'],
          parent_class: class_data['parent_class'],
          is_item_model: class_data['is_item_model'] == 1,
          interfaces: class_data['interfaces']&.split(', ')
        }.compact
      end

      def self.format_signature(signature_data)
        class_info = signature_data[:class]
        
        {
          class: {
            name: class_info['name'],
            type: class_info['type'],
            package: class_info['package'],
            extension: class_info['extension'],
            parent_class: class_info['parent_class'],
            interfaces: class_info['interfaces']&.split(', ') || [],
            file_path: class_info['file_path']
          },
          annotations: signature_data[:annotations].map { |a|
            a['annotation_value'] ? 
              "@#{a['annotation_name']}(#{a['annotation_value']})" : 
              "@#{a['annotation_name']}"
          },
          methods: signature_data[:methods].map { |m| format_method(m) }
        }
      end

      def self.format_method(method_data)
        {
          name: method_data['name'],
          signature: method_data['signature'],
          return_type: method_data['return_type'],
          modifiers: method_data['modifiers']&.split(' ') || [],
          is_constructor: method_data['is_constructor'] == 1,
          annotations: method_data['annotations']&.split(', ') || []
        }.compact
      end

      def self.format_bean(bean_data)
        {
          bean_id: bean_data['bean_id'],
          class_name: bean_data['class_name'],
          parent_bean: bean_data['parent_bean'],
          scope: bean_data['scope'],
          extension: bean_data['extension'],
          file_path: bean_data['file_path']
        }.compact
      end
    end
  end
end
