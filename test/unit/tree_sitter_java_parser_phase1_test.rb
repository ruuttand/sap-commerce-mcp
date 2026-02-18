# frozen_string_literal: true

require 'minitest/autorun'
require 'tree_sitter'
require_relative '../../lib/sap_commerce_mcp/parser/tree_sitter/grammar_loader'
require_relative '../../lib/sap_commerce_mcp/parser/tree_sitter_java_parser_phase1'

class TreeSitterJavaParserPhase1Test < Minitest::Test
  def setup
    @parser = SapCommerceMcp::Parser::TreeSitterJavaParserPhase1.new
    @fixtures_path = File.expand_path('../fixtures', __dir__)
  end

  def test_generic_class_extraction
    result = @parser.parse_file(File.join(@fixtures_path, 'GenericClass.java'))

    assert_equal 'GenericClass', result[:class_info][:name]
    assert_equal '<T extends Model>', result[:class_info][:generic_signature]
  end

  def test_generic_field_extraction
    result = @parser.parse_file(File.join(@fixtures_path, 'GenericClass.java'))

    product_cache = result[:fields].find { |f| f[:name] == 'productCache' }
    assert product_cache, "Should find productCache field"
    assert_equal 'Map<String, List<ProductModel>>', product_cache[:generic_type]

    items_field = result[:fields].find { |f| f[:name] == 'items' }
    assert items_field, "Should find items field"
    assert_equal 'List<T>', items_field[:generic_type]
  end

  def test_generic_method_extraction
    result = @parser.parse_file(File.join(@fixtures_path, 'GenericClass.java'))

    find_method = result[:methods].find { |m| m[:name] == 'findById' }
    assert find_method, "Should find findById method"
    assert_equal '<R extends Result>', find_method[:generic_signature]
    assert_equal 'R', find_method[:return_type]
  end

  def test_inner_class_extraction
    result = @parser.parse_file(File.join(@fixtures_path, 'InnerClassExample.java'))

    assert_equal 'OuterClass', result[:class_info][:name]
    refute result[:class_info][:is_inner_class]

    inner_classes = result[:inner_classes]
    assert inner_classes, "Should have inner classes"
    assert_equal 4, inner_classes.length  # Including DeeplyNestedClass

    static_inner = inner_classes.find { |c| c[:class_info][:name] == 'StaticInnerClass' }
    assert static_inner, "Should find StaticInnerClass"
    assert static_inner[:class_info][:is_inner_class]
    assert_equal 'OuterClass', static_inner[:class_info][:parent_class_name]
    assert_includes static_inner[:class_info][:modifiers], 'static'

    inner_class = inner_classes.find { |c| c[:class_info][:name] == 'InnerClass' }
    assert inner_class, "Should find InnerClass"
    assert inner_class[:class_info][:is_inner_class]

    private_inner = inner_classes.find { |c| c[:class_info][:name] == 'PrivateInnerClass' }
    assert private_inner, "Should find PrivateInnerClass"
    assert_includes private_inner[:class_info][:modifiers], 'private'
  end

  def test_complex_annotations
    result = @parser.parse_file(File.join(@fixtures_path, 'ComplexAnnotations.java'))

    # Class-level annotation
    class_annotations = result[:annotations]
    assert class_annotations.length > 0, "Should have class annotations"

    request_mapping = class_annotations.find { |a| a[:name] == 'RequestMapping' }
    assert request_mapping, "Should find RequestMapping annotation"

    # Parse the JSON parameters
    params = JSON.parse(request_mapping[:parameters]) if request_mapping[:parameters]
    assert params, "Should have parameters"
    assert_equal '"/api/products"', params['value']
  end

  def test_field_annotations
    result = @parser.parse_file(File.join(@fixtures_path, 'ComplexAnnotations.java'))

    service_field = result[:fields].find { |f| f[:name] == 'productService' }
    assert service_field, "Should find productService field"

    qualifier_ann = service_field[:annotations].find { |a| a[:name] == 'Qualifier' }
    assert qualifier_ann, "Should find Qualifier annotation on field"

    params = JSON.parse(qualifier_ann[:parameters]) if qualifier_ann[:parameters]
    assert params
    assert_equal '"defaultProductService"', params['value']
  end

  def test_method_annotations
    result = @parser.parse_file(File.join(@fixtures_path, 'ComplexAnnotations.java'))

    get_product = result[:methods].find { |m| m[:name] == 'getProduct' }
    assert get_product, "Should find getProduct method"

    request_mapping = get_product[:annotations].find { |a| a[:name] == 'RequestMapping' }
    assert request_mapping, "Should find RequestMapping annotation on method"
  end

  def test_deeply_nested_inner_class
    result = @parser.parse_file(File.join(@fixtures_path, 'InnerClassExample.java'))

    # DeeplyNestedClass should be extracted
    inner_classes = result[:inner_classes]
    deeply_nested = inner_classes.find { |c| c[:class_info][:name] == 'DeeplyNestedClass' }

    assert deeply_nested, "Should find DeeplyNestedClass"
    assert_equal 'InnerClass', deeply_nested[:class_info][:parent_class_name]
  end

  def test_backward_compatibility_with_simple_class
    result = @parser.parse_file(File.join(@fixtures_path, 'SimpleClass.java'))

    assert_equal 'SimpleClass', result[:class_info][:name]
    assert_equal 'class', result[:class_info][:type]
    assert_includes result[:class_info][:modifiers], 'public'
  end
end
