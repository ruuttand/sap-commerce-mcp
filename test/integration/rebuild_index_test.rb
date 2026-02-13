# frozen_string_literal: true

require_relative '../test_helper'

class RebuildIndexTest < Minitest::Test
  include IntegrationTestHelper

  # --- Skip when index exists and force=false ---

  def test_skip_rebuild_when_index_exists
    result = parse_response(
      SapCommerceMcp::Tools::RebuildIndex.call(
        force: false,
        server_context: server_context
      )
    )

    assert_equal 'skipped', result['status']
    assert_match(/already exists/i, result['message'])
    assert result.key?('last_indexed')
  end

  # --- Response structure for skipped rebuild ---

  def test_skipped_response_structure
    result = parse_response(
      SapCommerceMcp::Tools::RebuildIndex.call(
        force: false,
        server_context: server_context
      )
    )

    assert result.key?('status')
    assert result.key?('message')
    assert result.key?('last_indexed')
  end

  # NOTE: We do not test force=true here to avoid rebuilding the index
  # during test runs, which would be slow (~minutes). A dedicated
  # slow test could be added in a separate test suite if needed.
end
