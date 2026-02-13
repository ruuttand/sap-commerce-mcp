# frozen_string_literal: true

require_relative '../test_helper'

class GetClassSignatureTest < Minitest::Test
  include IntegrationTestHelper

  # --- Basic signature retrieval ---

  def test_get_signature_for_controller
    result = parse_response(
      SapCommerceMcp::Tools::GetClassSignature.call(
        class_name: 'com.tieto.kalmar.ws.controller.LoginController',
        server_context: server_context
      )
    )

    refute result.key?('error'), "Expected no error, got: #{result['error']}"
    assert_equal 'com.tieto.kalmar.ws.controller.LoginController', result['class']['name']
    assert_equal 'class', result['class']['type']
    assert result.key?('methods')
    assert result.key?('annotations')
  end

  # --- Class with annotations ---

  def test_signature_includes_class_annotations
    result = parse_response(
      SapCommerceMcp::Tools::GetClassSignature.call(
        class_name: 'com.tieto.kalmar.ws.controller.LoginController',
        server_context: server_context
      )
    )

    annotations = result['annotations']
    annotation_names = annotations.map { |a| a.gsub(/@(\w+).*/, '\1') }
    assert_includes annotation_names, 'Controller'
  end

  # --- Class with methods ---

  def test_signature_has_methods
    result = parse_response(
      SapCommerceMcp::Tools::GetClassSignature.call(
        class_name: 'com.tieto.kalmar.ws.controller.LoginController',
        server_context: server_context
      )
    )

    assert_operator result['methods'].size, :>=, 1
    method = result['methods'].first
    assert method.key?('name')
    assert method.key?('signature')
  end

  # --- Class extending another ---

  def test_signature_shows_parent_class
    result = parse_response(
      SapCommerceMcp::Tools::GetClassSignature.call(
        class_name: 'com.tieto.kalmar.core.user.impl.DefaultKalmarB2BCustomerService',
        server_context: server_context
      )
    )

    refute result.key?('error'), "Expected no error, got: #{result['error']}"
    assert result['class']['parent_class'], 'Expected a parent class'
  end

  # --- Class implementing interfaces ---

  def test_signature_shows_interfaces
    result = parse_response(
      SapCommerceMcp::Tools::GetClassSignature.call(
        class_name: 'com.tieto.kalmar.facades.users.replacementparts.impl.DefaultKalmarReplacementPartsFacade',
        server_context: server_context
      )
    )

    refute result.key?('error'), "Expected no error, got: #{result['error']}"
    interfaces = result['class']['interfaces']
    assert_kind_of Array, interfaces
    assert_operator interfaces.size, :>=, 1
    assert_includes interfaces, 'KalmarReplacementPartsFacade'
  end

  # --- Interface signature ---

  def test_get_signature_for_interface
    result = parse_response(
      SapCommerceMcp::Tools::GetClassSignature.call(
        class_name: 'com.tieto.kalmar.core.user.KalmarB2BCustomerService',
        server_context: server_context
      )
    )

    refute result.key?('error'), "Expected no error, got: #{result['error']}"
    assert_equal 'interface', result['class']['type']
  end

  # --- Method details ---

  def test_method_has_return_type_and_modifiers
    result = parse_response(
      SapCommerceMcp::Tools::GetClassSignature.call(
        class_name: 'com.tieto.kalmar.core.user.impl.DefaultKalmarB2BCustomerService',
        server_context: server_context
      )
    )

    methods = result['methods']
    method = methods.find { |m| m['name'] == 'canBuy' }
    assert method, "Expected to find 'canBuy' method"
    assert method.key?('return_type')
    assert method.key?('signature')
  end

  # --- Class not found ---

  def test_class_not_found
    result = parse_response(
      SapCommerceMcp::Tools::GetClassSignature.call(
        class_name: 'com.nonexistent.ClassName',
        server_context: server_context
      )
    )

    assert result.key?('error')
    assert_match(/not found/i, result['error'])
  end

  # --- Response structure ---

  def test_response_structure
    result = parse_response(
      SapCommerceMcp::Tools::GetClassSignature.call(
        class_name: 'com.tieto.kalmar.ws.controller.LoginController',
        server_context: server_context
      )
    )

    assert result.key?('class')
    class_info = result['class']
    assert class_info.key?('name')
    assert class_info.key?('type')
    assert class_info.key?('package')
    assert class_info.key?('extension')
    assert class_info.key?('file_path')
  end

  # --- Package info ---

  def test_package_is_correct
    result = parse_response(
      SapCommerceMcp::Tools::GetClassSignature.call(
        class_name: 'com.tieto.kalmar.ws.controller.LoginController',
        server_context: server_context
      )
    )

    assert_equal 'com.tieto.kalmar.ws.controller', result['class']['package']
  end
end
