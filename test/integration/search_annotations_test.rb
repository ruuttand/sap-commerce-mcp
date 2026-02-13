# frozen_string_literal: true

require_relative '../test_helper'

class SearchAnnotationsTest < Minitest::Test
  include IntegrationTestHelper

  # --- Search for @Controller classes ---

  def test_search_controller_annotation
    result = parse_response(
      SapCommerceMcp::Tools::SearchAnnotations.call(
        annotation_name: 'Controller',
        target_type: 'class',
        server_context: server_context
      )
    )

    assert_operator result['result_count'], :>=, 1
    assert_equal '@Controller', result['annotation']
  end

  # --- Search with @ prefix ---

  def test_search_with_at_prefix
    result = parse_response(
      SapCommerceMcp::Tools::SearchAnnotations.call(
        annotation_name: '@Controller',
        target_type: 'class',
        server_context: server_context
      )
    )

    assert_operator result['result_count'], :>=, 1
    assert_equal '@Controller', result['annotation']
  end

  # --- Search for @Component classes ---

  def test_search_component_annotation
    result = parse_response(
      SapCommerceMcp::Tools::SearchAnnotations.call(
        annotation_name: 'Component',
        target_type: 'class',
        server_context: server_context
      )
    )

    assert_operator result['result_count'], :>=, 1
  end

  # --- Search for @Autowired on methods ---

  def test_search_autowired_on_methods
    result = parse_response(
      SapCommerceMcp::Tools::SearchAnnotations.call(
        annotation_name: 'Autowired',
        target_type: 'method',
        server_context: server_context
      )
    )

    # There may or may not be method-level @Autowired in kalmar, but the call should work
    assert result.key?('result_count')
  end

  # --- Search for @Resource on fields ---

  def test_search_resource_on_fields
    result = parse_response(
      SapCommerceMcp::Tools::SearchAnnotations.call(
        annotation_name: 'Resource',
        target_type: 'field',
        server_context: server_context
      )
    )

    assert result.key?('result_count')
  end

  # --- Search 'all' target types ---

  def test_search_all_target_types
    result = parse_response(
      SapCommerceMcp::Tools::SearchAnnotations.call(
        annotation_name: 'RequestMapping',
        target_type: 'all',
        server_context: server_context
      )
    )

    assert result.key?('result_count')
    results = result['results']
    assert results.key?('classes') if results.is_a?(Hash)
  end

  # --- Search for @Required ---

  def test_search_required_annotation
    result = parse_response(
      SapCommerceMcp::Tools::SearchAnnotations.call(
        annotation_name: 'Required',
        target_type: 'method',
        server_context: server_context
      )
    )

    assert result.key?('result_count')
  end

  # --- No results for nonexistent annotation ---

  def test_no_results_for_nonexistent_annotation
    result = parse_response(
      SapCommerceMcp::Tools::SearchAnnotations.call(
        annotation_name: 'NonExistentAnnotation12345',
        server_context: server_context
      )
    )

    assert_equal 0, result['result_count']
  end

  # --- Limit ---

  def test_limit_results
    result = parse_response(
      SapCommerceMcp::Tools::SearchAnnotations.call(
        annotation_name: 'RequestMapping',
        target_type: 'class',
        limit: 3,
        server_context: server_context
      )
    )

    assert_operator result['result_count'], :<=, 3
  end

  # --- Response structure ---

  def test_response_structure
    result = parse_response(
      SapCommerceMcp::Tools::SearchAnnotations.call(
        annotation_name: 'Controller',
        target_type: 'class',
        server_context: server_context
      )
    )

    assert result.key?('annotation')
    assert result.key?('target_type')
    assert result.key?('result_count')
    assert result.key?('results')
  end
end
