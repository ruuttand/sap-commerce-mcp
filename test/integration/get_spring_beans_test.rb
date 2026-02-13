# frozen_string_literal: true

require_relative '../test_helper'

class GetSpringBeansTest < Minitest::Test
  include IntegrationTestHelper

  # --- Search by exact bean ID ---

  def test_search_exact_bean_id
    result = parse_response(
      SapCommerceMcp::Tools::GetSpringBeans.call(
        bean_id_pattern: 'acceleratorCoreSystemSetup',
        server_context: server_context
      )
    )

    assert_operator result['result_count'], :>=, 1
    bean_ids = result['beans'].map { |b| b['bean_id'] }
    assert_includes bean_ids, 'acceleratorCoreSystemSetup'
  end

  # --- Search with wildcard pattern ---

  def test_search_wildcard_pattern
    result = parse_response(
      SapCommerceMcp::Tools::GetSpringBeans.call(
        bean_id_pattern: '*EventListener',
        server_context: server_context
      )
    )

    assert_operator result['result_count'], :>=, 1
    result['beans'].each do |bean|
      assert bean['bean_id'].end_with?('EventListener'),
             "Expected #{bean['bean_id']} to end with EventListener"
    end
  end

  # --- Search with prefix wildcard ---

  def test_search_prefix_pattern
    result = parse_response(
      SapCommerceMcp::Tools::GetSpringBeans.call(
        bean_id_pattern: 'default*',
        server_context: server_context
      )
    )

    assert_operator result['result_count'], :>=, 1
    result['beans'].each do |bean|
      assert bean['bean_id'].start_with?('default'),
             "Expected #{bean['bean_id']} to start with 'default'"
    end
  end

  # --- Filter by extension ---

  def test_filter_by_extension
    result = parse_response(
      SapCommerceMcp::Tools::GetSpringBeans.call(
        bean_id_pattern: '*',
        extension: 'kalmarcore',
        server_context: server_context
      )
    )

    assert_operator result['result_count'], :>=, 1
    result['beans'].each do |bean|
      assert_equal 'kalmarcore', bean['extension']
    end
  end

  # --- Filter by extension with specific pattern ---

  def test_filter_by_extension_and_pattern
    result = parse_response(
      SapCommerceMcp::Tools::GetSpringBeans.call(
        bean_id_pattern: '*Facade',
        extension: 'kalmarfacades',
        server_context: server_context
      )
    )

    assert_operator result['result_count'], :>=, 1
    result['beans'].each do |bean|
      assert_equal 'kalmarfacades', bean['extension']
    end
  end

  # --- Bean with parent ---

  def test_bean_with_parent
    result = parse_response(
      SapCommerceMcp::Tools::GetSpringBeans.call(
        bean_id_pattern: 'acceleratorCoreSystemSetup',
        server_context: server_context
      )
    )

    bean = result['beans'].find { |b| b['bean_id'] == 'acceleratorCoreSystemSetup' }
    assert bean, 'Expected to find acceleratorCoreSystemSetup bean'
    assert bean['parent_bean'], 'Expected bean to have a parent'
  end

  # --- No results ---

  def test_no_results_for_nonexistent_bean
    result = parse_response(
      SapCommerceMcp::Tools::GetSpringBeans.call(
        bean_id_pattern: 'nonExistentBeanId12345',
        server_context: server_context
      )
    )

    assert_equal 0, result['result_count']
    assert_empty result['beans']
  end

  # --- Limit ---

  def test_limit_results
    result = parse_response(
      SapCommerceMcp::Tools::GetSpringBeans.call(
        bean_id_pattern: '*',
        limit: 3,
        server_context: server_context
      )
    )

    assert_operator result['result_count'], :<=, 3
  end

  # --- Response structure ---

  def test_response_structure
    result = parse_response(
      SapCommerceMcp::Tools::GetSpringBeans.call(
        bean_id_pattern: 'acceleratorCoreSystemSetup',
        server_context: server_context
      )
    )

    assert result.key?('pattern')
    assert result.key?('result_count')
    assert result.key?('beans')

    if result['result_count'] > 0
      bean = result['beans'].first
      assert bean.key?('bean_id')
      assert bean.key?('class_name')
      assert bean.key?('extension')
    end
  end

  # --- Bean with scope ---

  def test_bean_with_prototype_scope
    result = parse_response(
      SapCommerceMcp::Tools::GetSpringBeans.call(
        bean_id_pattern: 'customerEmailContext',
        server_context: server_context
      )
    )

    if result['result_count'] > 0
      bean = result['beans'].find { |b| b['bean_id'] == 'customerEmailContext' }
      assert_equal 'prototype', bean['scope'] if bean
    end
  end
end
