# frozen_string_literal: true

require 'minitest/autorun'
require 'tree_sitter'  # Explicitly require since gem has 'require: false'
require_relative '../../lib/sap_commerce_mcp/parser/tree_sitter/grammar_loader'
require_relative '../../lib/sap_commerce_mcp/parser/tree_sitter_java_parser'

class TreeSitterJavaParserTest < Minitest::Test
  def setup
    @parser = SapCommerceMcp::Parser::TreeSitterJavaParser.new
    @fixtures_path = File.expand_path('../fixtures', __dir__)
  end

  def test_extract_package
    result = @parser.parse_file(File.join(@fixtures_path, 'SimpleClass.java'))

    assert_equal 'com.example.test', result[:package]
  end

  def test_extract_imports
    result = @parser.parse_file(File.join(@fixtures_path, 'ClassWithExtends.java'))

    assert_includes result[:imports], 'com.example.BaseClass'
  end

  def test_extract_multiple_imports
    result = @parser.parse_file(File.join(@fixtures_path, 'ClassWithImplements.java'))

    assert_equal 2, result[:imports].length
    assert_includes result[:imports], 'com.example.Interface1'
    assert_includes result[:imports], 'com.example.Interface2'
  end

  def test_extract_class_info_simple
    result = @parser.parse_file(File.join(@fixtures_path, 'SimpleClass.java'))

    assert_equal 'SimpleClass', result[:class_info][:name]
    assert_equal 'class', result[:class_info][:type]
    assert_includes result[:class_info][:modifiers], 'public'
    assert_nil result[:class_info][:extends]
    assert_empty result[:class_info][:implements]
    refute result[:class_info][:is_abstract]
  end

  def test_extract_class_with_extends
    result = @parser.parse_file(File.join(@fixtures_path, 'ClassWithExtends.java'))

    assert_equal 'MyClass', result[:class_info][:name]
    assert_equal 'class', result[:class_info][:type]
    assert_equal 'BaseClass', result[:class_info][:extends]
  end

  def test_extract_class_with_implements
    result = @parser.parse_file(File.join(@fixtures_path, 'ClassWithImplements.java'))

    assert_equal 'MyClass', result[:class_info][:name]
    assert_equal 2, result[:class_info][:implements].length
    assert_includes result[:class_info][:implements], 'Interface1'
    assert_includes result[:class_info][:implements], 'Interface2'
  end

  def test_extract_interface
    result = @parser.parse_file(File.join(@fixtures_path, 'InterfaceDeclaration.java'))

    assert_equal 'MyInterface', result[:class_info][:name]
    assert_equal 'interface', result[:class_info][:type]
    assert_equal 'BaseInterface', result[:class_info][:extends]
    assert_empty result[:class_info][:implements]
  end

  def test_extract_enum
    result = @parser.parse_file(File.join(@fixtures_path, 'EnumDeclaration.java'))

    assert_equal 'MyEnum', result[:class_info][:name]
    assert_equal 'enum', result[:class_info][:type]
    assert_nil result[:class_info][:extends]
  end

  def test_extract_abstract_class
    result = @parser.parse_file(File.join(@fixtures_path, 'AbstractClass.java'))

    assert_equal 'AbstractClass', result[:class_info][:name]
    assert_equal 'abstract', result[:class_info][:type]
    assert result[:class_info][:is_abstract]
    assert_includes result[:class_info][:modifiers], 'abstract'
  end

  def test_parse_file_returns_expected_structure
    result = @parser.parse_file(File.join(@fixtures_path, 'SimpleClass.java'))

    # Verify all expected keys are present
    assert_respond_to result, :[]
    assert result.key?(:package)
    assert result.key?(:imports)
    assert result.key?(:class_info)
    assert result.key?(:methods)
    assert result.key?(:fields)
    assert result.key?(:annotations)
    assert result.key?(:constructor_params)

    # Verify POC scope - these should be empty
    assert_empty result[:methods]
    assert_empty result[:fields]
    assert_empty result[:annotations]
    assert_empty result[:constructor_params]
  end

  def test_handles_malformed_java_gracefully
    # Create a temporary malformed Java file
    malformed_file = File.join(@fixtures_path, 'malformed_temp.java')
    File.write(malformed_file, "this is not valid java code }{")

    result = @parser.parse_file(malformed_file)

    # Should not crash, but may return nil or partial data
    # The important thing is it doesn't raise an exception
    assert_nil result[:class_info] if result
  ensure
    File.delete(malformed_file) if File.exist?(malformed_file)
  end
end
