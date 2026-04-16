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

# Conditionally load tree-sitter parser if gem is available
begin
  require 'pathname'
  # Set TREE_SITTER_PARSERS before requiring tree_sitter gem, because the gem
  # evaluates ENV_PARSERS at require-time as a frozen constant.
  grammar_dir = File.expand_path('~/.sap-commerce-mcp/grammars')
  existing = ENV['TREE_SITTER_PARSERS']
  if existing
    ENV['TREE_SITTER_PARSERS'] = "#{grammar_dir}:#{existing}" unless existing.include?(grammar_dir)
  else
    ENV['TREE_SITTER_PARSERS'] = grammar_dir
  end
  require 'tree_sitter'
  require_relative 'sap_commerce_mcp/parser/tree_sitter/grammar_loader'
  require_relative 'sap_commerce_mcp/parser/tree_sitter_java_parser'
rescue LoadError
  # tree_sitter gem not available, tree-sitter parser will not be available
end

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
    FileUtils.mkdir_p(File.join(data_dir, 'grammars'))
  end
end

# Load all tool classes
require_relative 'sap_commerce_mcp/tools/search_classes'
require_relative 'sap_commerce_mcp/tools/get_class_signature'
require_relative 'sap_commerce_mcp/tools/find_implementations'
require_relative 'sap_commerce_mcp/tools/find_injected_dependencies'
require_relative 'sap_commerce_mcp/tools/remaining_tools'