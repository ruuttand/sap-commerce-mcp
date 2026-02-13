# frozen_string_literal: true

require_relative '../test_helper'

class SearchClassesTest < Minitest::Test
  include IntegrationTestHelper

  # --- Exact name search ---

  def test_search_by_exact_simple_name
    result = parse_response(
      SapCommerceMcp::Tools::SearchClasses.call(
        query: 'LoginController',
        server_context: server_context
      )
    )

    assert_operator result['result_count'], :>=, 1
    names = result['results'].map { |r| r['simple_name'] }
    assert_includes names, 'LoginController'
  end

  def test_search_by_fully_qualified_name
    result = parse_response(
      SapCommerceMcp::Tools::SearchClasses.call(
        query: 'com.tieto.kalmar.ws.controller.LoginController',
        server_context: server_context
      )
    )

    assert_operator result['result_count'], :>=, 1
    assert_equal 'com.tieto.kalmar.ws.controller.LoginController',
                 result['results'].first['name']
  end

  # --- Wildcard pattern search ---

  def test_search_with_wildcard_suffix
    result = parse_response(
      SapCommerceMcp::Tools::SearchClasses.call(
        query: '*Controller',
        filters: { 'extension' => 'kalmarws' },
        server_context: server_context
      )
    )

    assert_operator result['result_count'], :>=, 1
    result['results'].each do |r|
      assert r['simple_name'].end_with?('Controller'),
             "Expected #{r['simple_name']} to end with Controller"
    end
  end

  def test_search_with_wildcard_prefix
    result = parse_response(
      SapCommerceMcp::Tools::SearchClasses.call(
        query: 'Default*Facade',
        server_context: server_context
      )
    )

    assert_operator result['result_count'], :>=, 1
    result['results'].each do |r|
      assert r['simple_name'].start_with?('Default'),
             "Expected #{r['simple_name']} to start with Default"
      assert r['simple_name'].end_with?('Facade'),
             "Expected #{r['simple_name']} to end with Facade"
    end
  end

  # --- Filter by type ---

  def test_filter_by_interface_type
    result = parse_response(
      SapCommerceMcp::Tools::SearchClasses.call(
        query: 'KalmarB2BCustomerService',
        filters: { 'type' => 'interface' },
        server_context: server_context
      )
    )

    assert_operator result['result_count'], :>=, 1
    result['results'].each do |r|
      assert_equal 'interface', r['type']
    end
  end

  def test_filter_by_enum_type
    result = parse_response(
      SapCommerceMcp::Tools::SearchClasses.call(
        query: 'MachineIconsEnum',
        filters: { 'type' => 'enum' },
        server_context: server_context
      )
    )

    assert_operator result['result_count'], :>=, 1
    result['results'].each do |r|
      assert_equal 'enum', r['type']
    end
  end

  # --- Filter by extension ---

  def test_filter_by_extension
    result = parse_response(
      SapCommerceMcp::Tools::SearchClasses.call(
        query: 'Kalmar',
        filters: { 'extension' => 'kalmarcore' },
        server_context: server_context
      )
    )

    assert_operator result['result_count'], :>=, 1
    result['results'].each do |r|
      assert_equal 'kalmarcore', r['extension']
    end
  end

  # --- Filter by annotation ---

  def test_filter_by_controller_annotation
    result = parse_response(
      SapCommerceMcp::Tools::SearchClasses.call(
        query: '*',
        filters: { 'annotation' => 'Controller' },
        server_context: server_context
      )
    )

    assert_operator result['result_count'], :>=, 1
  end

  def test_filter_by_annotation_with_at_prefix
    result = parse_response(
      SapCommerceMcp::Tools::SearchClasses.call(
        query: '*',
        filters: { 'annotation' => '@Component' },
        server_context: server_context
      )
    )

    assert_operator result['result_count'], :>=, 1
  end

  # --- Limit ---

  def test_limit_results
    result = parse_response(
      SapCommerceMcp::Tools::SearchClasses.call(
        query: '*',
        limit: 5,
        server_context: server_context
      )
    )

    assert_operator result['result_count'], :<=, 5
  end

  # --- No results ---

  def test_no_results_for_nonexistent_class
    result = parse_response(
      SapCommerceMcp::Tools::SearchClasses.call(
        query: 'ThisClassDefinitelyDoesNotExist12345',
        server_context: server_context
      )
    )

    assert_equal 0, result['result_count']
    assert_empty result['results']
  end

  # --- Response structure ---

  def test_response_structure
    result = parse_response(
      SapCommerceMcp::Tools::SearchClasses.call(
        query: 'LoginController',
        server_context: server_context
      )
    )

    assert result.key?('query')
    assert result.key?('filters')
    assert result.key?('result_count')
    assert result.key?('results')

    entry = result['results'].first
    assert entry.key?('name')
    assert entry.key?('simple_name')
    assert entry.key?('type')
    assert entry.key?('extension')
    assert entry.key?('file_path')
  end

  # --- Combined filters ---

  def test_combined_type_and_extension_filters
    result = parse_response(
      SapCommerceMcp::Tools::SearchClasses.call(
        query: 'Kalmar',
        filters: { 'type' => 'class', 'extension' => 'kalmarfacades' },
        server_context: server_context
      )
    )

    assert_operator result['result_count'], :>=, 1
    result['results'].each do |r|
      assert_equal 'class', r['type']
      assert_equal 'kalmarfacades', r['extension']
    end
  end
end
