# frozen_string_literal: true

require_relative '../test_helper'

class FindInjectedDependenciesTest < Minitest::Test
  include IntegrationTestHelper

  # ========================================
  # Mode 1: Find dependencies OF a class
  # ========================================

  # --- Field injection with @Autowired ---

  def test_find_autowired_field_dependencies
    response = SapCommerceMcp::Tools::FindInjectedDependencies.call(
      class_name: 'LoginController',
      annotation: 'Autowired',
      server_context: server_context
    )

    text = response.content.first[:text] || response.content.first['text']
    refute text.start_with?('Error:'), "Unexpected error: #{text}"
    # LoginController has @Autowired fields (tokenLoginFacade, kalmarUserFacade, etc.)
    assert_match(/Injected Dependencies/i, text)
  end

  # --- Field injection with @Resource ---

  def test_find_resource_field_dependencies
    response = SapCommerceMcp::Tools::FindInjectedDependencies.call(
      class_name: 'LoginController',
      annotation: 'Resource',
      server_context: server_context
    )

    text = response.content.first[:text] || response.content.first['text']
    refute text.start_with?('Error:'), "Unexpected error: #{text}"
    # LoginController has @Resource(name = "authenticationManager")
    assert_match(/authenticationManager|Resource/i, text)
  end

  # --- All injection types for a class ---

  def test_find_all_dependencies_of_class
    response = SapCommerceMcp::Tools::FindInjectedDependencies.call(
      class_name: 'LoginController',
      server_context: server_context
    )

    text = response.content.first[:text] || response.content.first['text']
    refute text.start_with?('Error:'), "Unexpected error: #{text}"
    assert_match(/Injected Dependencies/i, text)
  end

  # --- XML dependencies ---

  def test_find_xml_dependencies
    response = SapCommerceMcp::Tools::FindInjectedDependencies.call(
      class_name: 'com.tieto.kalmar.core.event.OrderCancelledEventListener',
      server_context: server_context
    )

    text = response.content.first[:text] || response.content.first['text']
    # This class is configured via Spring XML with property refs
    refute text.start_with?('Error:'), "Unexpected error: #{text}"
  end

  # --- Facade with setter injection ---

  def test_find_setter_injection_dependencies
    response = SapCommerceMcp::Tools::FindInjectedDependencies.call(
      class_name: 'DefaultKalmarB2BCustomerService',
      server_context: server_context
    )

    text = response.content.first[:text] || response.content.first['text']
    refute text.start_with?('Error:'), "Unexpected error: #{text}"
  end

  # --- No dependencies found ---

  def test_no_dependencies_for_nonexistent_class
    response = SapCommerceMcp::Tools::FindInjectedDependencies.call(
      class_name: 'NonExistentClass12345',
      server_context: server_context
    )

    text = response.content.first[:text] || response.content.first['text']
    assert_match(/no injected dependencies found/i, text)
  end

  # ========================================
  # Mode 2: Find classes injecting a type
  # ========================================

  # --- Find who injects a service ---

  def test_find_classes_injecting_type
    response = SapCommerceMcp::Tools::FindInjectedDependencies.call(
      injected_type: 'TokenLoginFacade',
      server_context: server_context
    )

    text = response.content.first[:text] || response.content.first['text']
    refute text.start_with?('Error:'), "Unexpected error: #{text}"
    # LoginController has @Autowired TokenLoginFacade
    assert_match(/LoginController|Classes Injecting/i, text)
  end

  # --- Find who injects with annotation filter ---

  def test_find_classes_injecting_type_with_annotation_filter
    response = SapCommerceMcp::Tools::FindInjectedDependencies.call(
      injected_type: 'AuthenticationManager',
      annotation: 'Resource',
      server_context: server_context
    )

    text = response.content.first[:text] || response.content.first['text']
    refute text.start_with?('Error:'), "Unexpected error: #{text}"
  end

  # --- No classes injecting nonexistent type ---

  def test_no_classes_injecting_nonexistent_type
    response = SapCommerceMcp::Tools::FindInjectedDependencies.call(
      injected_type: 'NonExistentType12345',
      server_context: server_context
    )

    text = response.content.first[:text] || response.content.first['text']
    assert_match(/no classes found injecting/i, text)
  end

  # ========================================
  # Validation
  # ========================================

  # --- Error when neither class_name nor injected_type provided ---

  def test_error_when_no_mode_specified
    response = SapCommerceMcp::Tools::FindInjectedDependencies.call(
      server_context: server_context
    )

    text = response.content.first[:text] || response.content.first['text']
    assert_match(/error.*class_name.*injected_type/i, text)
  end

  # --- Partial class name matching ---

  def test_partial_class_name_matching
    response = SapCommerceMcp::Tools::FindInjectedDependencies.call(
      class_name: 'ErrorMailerServiceActivator',
      server_context: server_context
    )

    text = response.content.first[:text] || response.content.first['text']
    refute text.start_with?('Error:'), "Unexpected error: #{text}"
  end

  # --- Response format for dependencies of class ---

  def test_response_format_dependencies_of_class
    response = SapCommerceMcp::Tools::FindInjectedDependencies.call(
      class_name: 'LoginController',
      server_context: server_context
    )

    text = response.content.first[:text] || response.content.first['text']
    refute text.start_with?('Error:'), "Unexpected error: #{text}"

    # Should have markdown headers
    assert_match(/^#/, text) if text.include?('Injected Dependencies')
  end
end
