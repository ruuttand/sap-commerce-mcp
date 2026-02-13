# frozen_string_literal: true

require 'bundler/setup'
require 'minitest/autorun'
require 'minitest/reporters'
require 'json'

Minitest::Reporters.use!(Minitest::Reporters::SpecReporter.new)

require_relative '../lib/sap_commerce_mcp'

# Path to the Kalmar hybris project used for integration tests
HYBRIS_PROJECT_PATH = '/Users/andree.ruut_1_2/git/kalmarstore/kalmar-hybris'

module IntegrationTestHelper
  def self.server_context
    @server_context ||= begin
      indexer = SapCommerceMcp::Indexer.new(HYBRIS_PROJECT_PATH)

      unless indexer.index_exists?
        warn "Building index for #{HYBRIS_PROJECT_PATH}..."
        indexer.build_index
      end

      indexer.ensure_db_open

      audit_logger = SapCommerceMcp::Audit::Logger.new(HYBRIS_PROJECT_PATH)

      {
        indexer: indexer,
        audit_logger: audit_logger,
        project_path: HYBRIS_PROJECT_PATH
      }
    end
  end

  def server_context
    IntegrationTestHelper.server_context
  end

  # Parse the JSON text from an MCP::Tool::Response
  def parse_response(response)
    assert_kind_of MCP::Tool::Response, response
    text = response.content.first[:text] || response.content.first['text']
    JSON.parse(text)
  end
end
