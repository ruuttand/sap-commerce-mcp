# frozen_string_literal: true

require 'mcp'
require 'sqlite3'
require 'concurrent'
require 'fileutils'
require 'json'

# Load all components first
require_relative 'sap_commerce_mcp/indexer'
require_relative 'sap_commerce_mcp/parser/java_parser'
require_relative 'sap_commerce_mcp/parser/sap_commerce_parser'
require_relative 'sap_commerce_mcp/search/query_processor'
require_relative 'sap_commerce_mcp/search/result_formatter'
require_relative 'sap_commerce_mcp/audit/logger'

module SapCommerceMcp
  class Error < StandardError; end

  def self.root
    File.expand_path('../..', __FILE__)
  end

  def self.data_dir
    File.expand_path('~/.sap-commerce-mcp')
  end

  def self.ensure_data_dir!
    FileUtils.mkdir_p(data_dir)
    FileUtils.mkdir_p(File.join(data_dir, 'logs'))
    FileUtils.mkdir_p(File.join(data_dir, 'indexes'))
  end
end

# Load all tool classes
require_relative 'sap_commerce_mcp/tools/search_classes'
require_relative 'sap_commerce_mcp/tools/get_class_signature'
require_relative 'sap_commerce_mcp/tools/find_implementations'
require_relative 'sap_commerce_mcp/tools/remaining_tools'