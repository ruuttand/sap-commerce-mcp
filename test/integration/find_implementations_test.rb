# frozen_string_literal: true

require_relative '../test_helper'

class FindImplementationsTest < Minitest::Test
  include IntegrationTestHelper

  # --- Find implementations of an interface (simple name) ---
  # Note: Interfaces are stored as simple names in class_interfaces table

  def test_find_implementations_of_interface
    result = parse_response(
      SapCommerceMcp::Tools::FindImplementations.call(
        class_or_interface: 'WarehouseAllocationService',
        server_context: server_context
      )
    )

    assert_operator result['result_count'], :>=, 1
    assert result.key?('implementations')
    names = result['implementations'].map { |r| r['simple_name'] }
    assert_includes names, 'DefaultWarehouseAllocationService'
  end

  # --- Find implementations of a facade interface ---

  def test_find_implementations_of_facade_interface
    result = parse_response(
      SapCommerceMcp::Tools::FindImplementations.call(
        class_or_interface: 'KalmarReplacementPartsFacade',
        server_context: server_context
      )
    )

    assert_operator result['result_count'], :>=, 1
    names = result['implementations'].map { |r| r['simple_name'] }
    assert_includes names, 'DefaultKalmarReplacementPartsFacade'
  end

  # --- Find subclasses of an abstract class ---

  def test_find_subclasses_of_abstract_class
    result = parse_response(
      SapCommerceMcp::Tools::FindImplementations.call(
        class_or_interface: 'AbstractFraudCheckAction',
        server_context: server_context
      )
    )

    # AbstractFraudCheckAction may have concrete implementations via parent_class
    assert result.key?('implementations')
  end

  # --- Find implementations of KalmarB2BCustomerService ---

  def test_find_implementations_of_service_interface
    result = parse_response(
      SapCommerceMcp::Tools::FindImplementations.call(
        class_or_interface: 'KalmarMachinePartsService',
        server_context: server_context
      )
    )

    assert_operator result['result_count'], :>=, 1
    names = result['implementations'].map { |r| r['simple_name'] }
    assert_includes names, 'DefaultKalmarMachinePartsService'
  end

  # --- No implementations found ---

  def test_no_implementations_for_nonexistent_interface
    result = parse_response(
      SapCommerceMcp::Tools::FindImplementations.call(
        class_or_interface: 'InterfaceThatDoesNotExist12345',
        server_context: server_context
      )
    )

    assert_equal 0, result['result_count']
    assert_empty result['implementations']
  end

  # --- Limit ---

  def test_limit_results
    result = parse_response(
      SapCommerceMcp::Tools::FindImplementations.call(
        class_or_interface: 'WarehouseAllocationService',
        limit: 1,
        server_context: server_context
      )
    )

    assert_operator result['result_count'], :<=, 1
  end

  # --- Response structure ---

  def test_response_structure
    result = parse_response(
      SapCommerceMcp::Tools::FindImplementations.call(
        class_or_interface: 'WarehouseAllocationService',
        server_context: server_context
      )
    )

    assert result.key?('interface')
    assert result.key?('result_count')
    assert result.key?('implementations')

    if result['result_count'] > 0
      impl = result['implementations'].first
      assert impl.key?('name')
      assert impl.key?('simple_name')
      assert impl.key?('type')
      assert impl.key?('extension')
    end
  end

  # --- Interface name is echoed back ---

  def test_interface_name_in_response
    interface = 'WarehouseAllocationService'
    result = parse_response(
      SapCommerceMcp::Tools::FindImplementations.call(
        class_or_interface: interface,
        server_context: server_context
      )
    )

    assert_equal interface, result['interface']
  end
end
