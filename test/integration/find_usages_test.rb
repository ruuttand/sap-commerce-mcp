# frozen_string_literal: true

require_relative '../test_helper'

class FindUsagesTest < Minitest::Test
  include IntegrationTestHelper

  # --- Find usages of a commonly imported class ---

  def test_find_usages_of_service_interface
    result = parse_response(
      SapCommerceMcp::Tools::FindUsages.call(
        class_name: 'com.tieto.kalmar.core.user.KalmarB2BCustomerService',
        server_context: server_context
      )
    )

    assert_operator result['result_count'], :>=, 1
    assert result.key?('usages')
  end

  # --- Find usages by fully qualified name ---

  def test_find_usages_of_warehouse_service
    result = parse_response(
      SapCommerceMcp::Tools::FindUsages.call(
        class_name: 'com.tieto.kalmar.core.warehouse.WarehouseAllocationService',
        server_context: server_context
      )
    )

    assert_operator result['result_count'], :>=, 1
    result['usages'].each do |usage|
      assert usage.key?('name')
      assert usage.key?('file_path')
    end
  end

  # --- No usages for nonexistent class ---

  def test_no_usages_for_nonexistent_class
    result = parse_response(
      SapCommerceMcp::Tools::FindUsages.call(
        class_name: 'com.nonexistent.ClassThatDoesNotExist',
        server_context: server_context
      )
    )

    assert_equal 0, result['result_count']
    assert_empty result['usages']
  end

  # --- Limit ---

  def test_limit_results
    result = parse_response(
      SapCommerceMcp::Tools::FindUsages.call(
        class_name: 'com.tieto.kalmar.core.user.KalmarB2BCustomerService',
        limit: 2,
        server_context: server_context
      )
    )

    assert_operator result['result_count'], :<=, 2
  end

  # --- Response structure ---

  def test_response_structure
    result = parse_response(
      SapCommerceMcp::Tools::FindUsages.call(
        class_name: 'com.tieto.kalmar.core.user.KalmarB2BCustomerService',
        server_context: server_context
      )
    )

    assert result.key?('class')
    assert result.key?('result_count')
    assert result.key?('usages')

    if result['result_count'] > 0
      usage = result['usages'].first
      assert usage.key?('name')
      assert usage.key?('file_path')
      assert usage.key?('extension')
    end
  end

  # --- Class name echoed in response ---

  def test_class_name_in_response
    class_name = 'com.tieto.kalmar.core.user.KalmarB2BCustomerService'
    result = parse_response(
      SapCommerceMcp::Tools::FindUsages.call(
        class_name: class_name,
        server_context: server_context
      )
    )

    assert_equal class_name, result['class']
  end
end
