# frozen_string_literal: true

require_relative '../test_helper'

class GetIndexStatsTest < Minitest::Test
  include IntegrationTestHelper

  # --- Stats are returned ---

  def test_returns_stats
    result = parse_response(
      SapCommerceMcp::Tools::GetIndexStats.call(
        server_context: server_context
      )
    )

    assert result.key?('classes_count')
    assert result.key?('methods_count')
    assert result.key?('fields_count')
    assert result.key?('annotations_count')
    assert result.key?('beans_count')
    assert result.key?('extensions_count')
    assert result.key?('index_size_bytes')
  end

  # --- Counts are non-negative ---

  def test_counts_are_positive
    result = parse_response(
      SapCommerceMcp::Tools::GetIndexStats.call(
        server_context: server_context
      )
    )

    assert_operator result['classes_count'], :>, 0
    assert_operator result['methods_count'], :>, 0
    assert_operator result['fields_count'], :>, 0
    assert_operator result['annotations_count'], :>, 0
    assert_operator result['beans_count'], :>, 0
    assert_operator result['extensions_count'], :>, 0
    assert_operator result['index_size_bytes'], :>, 0
  end

  # --- Last indexed time is present ---

  def test_last_indexed_time
    result = parse_response(
      SapCommerceMcp::Tools::GetIndexStats.call(
        server_context: server_context
      )
    )

    assert result['last_indexed'], 'Expected last_indexed to be present'
    assert_match(/\d{4}-\d{2}-\d{2}/, result['last_indexed'])
  end

  # --- Reasonable class count for kalmar project ---

  def test_reasonable_class_count
    result = parse_response(
      SapCommerceMcp::Tools::GetIndexStats.call(
        server_context: server_context
      )
    )

    # Kalmar project should have at least 50 custom classes
    assert_operator result['classes_count'], :>=, 50,
                    "Expected at least 50 classes, got #{result['classes_count']}"
  end

  # --- Multiple extensions indexed ---

  def test_multiple_extensions
    result = parse_response(
      SapCommerceMcp::Tools::GetIndexStats.call(
        server_context: server_context
      )
    )

    # Kalmar has many custom extensions
    assert_operator result['extensions_count'], :>=, 3,
                    "Expected at least 3 extensions, got #{result['extensions_count']}"
  end
end
