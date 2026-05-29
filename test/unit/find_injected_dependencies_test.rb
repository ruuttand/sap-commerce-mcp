# frozen_string_literal: true

require 'minitest/autorun'
require 'sqlite3'

# Stub MCP::Tool so we can load the tool class without the full MCP gem
module MCP
  class Tool
    def self.title(*)
    end

    def self.description(*)
    end

    def self.input_schema(*)
    end
  end
end

require_relative '../../lib/sap_commerce_mcp/tools/find_injected_dependencies'

class FindInjectedDependenciesTest < Minitest::Test
  # Build a minimal in-memory DB with the schema tables the tool queries
  def setup
    @db = SQLite3::Database.new(':memory:')
    @db.results_as_hash = true

    @db.execute_batch(<<~SQL)
      CREATE TABLE classes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        simple_name TEXT NOT NULL,
        package TEXT NOT NULL,
        file_path TEXT NOT NULL,
        extension TEXT,
        type TEXT NOT NULL,
        parent_class TEXT,
        parent_class_id INTEGER,
        generic_signature TEXT,
        is_item_model INTEGER DEFAULT 0,
        is_inner_class INTEGER DEFAULT 0
      );
      CREATE TABLE fields (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        class_id INTEGER,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        generic_type TEXT,
        modifiers TEXT
      );
      CREATE TABLE methods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        class_id INTEGER,
        name TEXT NOT NULL,
        signature TEXT NOT NULL,
        return_type TEXT,
        generic_signature TEXT,
        modifiers TEXT,
        is_constructor INTEGER DEFAULT 0
      );
      CREATE TABLE annotations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        target_type TEXT,
        target_id INTEGER,
        annotation_name TEXT NOT NULL,
        annotation_value TEXT,
        parameters TEXT
      );
    SQL

    @tool = SapCommerceMcp::Tools::FindInjectedDependencies
  end

  def teardown
    @db.close
  end

  # --- helpers ---

  def insert_class(name, extension: 'warehouse')
    @db.execute(
      "INSERT INTO classes (name, simple_name, package, file_path, extension, type) VALUES (?, ?, ?, ?, ?, ?)",
      [name, name.split('.').last, 'com.example', "/src/#{name}.java", extension, 'class']
    )
    @db.last_insert_row_id
  end

  def insert_field(class_id, name, type, modifiers: nil)
    @db.execute(
      "INSERT INTO fields (class_id, name, type, modifiers) VALUES (?, ?, ?, ?)",
      [class_id, name, type, modifiers]
    )
    @db.last_insert_row_id
  end

  def insert_method(class_id, name, return_type:, signature: nil)
    @db.execute(
      "INSERT INTO methods (class_id, name, signature, return_type) VALUES (?, ?, ?, ?)",
      [class_id, name, signature || "#{name}()", return_type]
    )
    @db.last_insert_row_id
  end

  def insert_annotation(target_type, target_id, annotation_name)
    @db.execute(
      "INSERT INTO annotations (target_type, target_id, annotation_name) VALUES (?, ?, ?)",
      [target_type, target_id, annotation_name]
    )
  end

  def convention_deps(class_name)
    @tool.send(:find_convention_field_injections, @db, class_name)
  end

  def convention_injectors(injected_type)
    @tool.send(:find_convention_setter_injections_of_type, @db, injected_type)
  end

  # --- Mode 1: find_convention_field_injections ---

  def test_detects_unannotated_field_with_matching_setter
    cid = insert_class('DefaultWarehouseAllocationService')
    insert_field(cid, 'availabilityService', 'AvailabilityService')
    insert_method(cid, 'setAvailabilityService', return_type: 'void')

    results = convention_deps('DefaultWarehouseAllocationService')

    assert_equal 1, results.size
    assert_equal 'availabilityService', results.first['dependency_name']
    assert_equal 'AvailabilityService', results.first['dependency_type']
  end

  def test_skips_field_already_annotated_with_autowired
    cid = insert_class('DefaultCheckoutFacade')
    fid = insert_field(cid, 'cartService', 'CartService')
    insert_annotation('field', fid, 'Autowired')
    insert_method(cid, 'setCartService', return_type: 'void')

    results = convention_deps('DefaultCheckoutFacade')

    assert_empty results
  end

  def test_skips_field_annotated_with_resource
    cid = insert_class('DefaultCheckoutFacade')
    fid = insert_field(cid, 'cartService', 'CartService')
    insert_annotation('field', fid, 'Resource')
    insert_method(cid, 'setCartService', return_type: 'void')

    assert_empty convention_deps('DefaultCheckoutFacade')
  end

  def test_skips_field_annotated_with_inject
    cid = insert_class('DefaultCheckoutFacade')
    fid = insert_field(cid, 'cartService', 'CartService')
    insert_annotation('field', fid, 'Inject')
    insert_method(cid, 'setCartService', return_type: 'void')

    assert_empty convention_deps('DefaultCheckoutFacade')
  end

  def test_skips_field_without_matching_setter
    cid = insert_class('DefaultWarehouseAllocationService')
    insert_field(cid, 'availabilityService', 'AvailabilityService')
    # no setter

    assert_empty convention_deps('DefaultWarehouseAllocationService')
  end

  def test_skips_setter_that_does_not_return_void
    cid = insert_class('DefaultWarehouseAllocationService')
    insert_field(cid, 'availabilityService', 'AvailabilityService')
    insert_method(cid, 'setAvailabilityService', return_type: 'AvailabilityService')  # builder pattern

    assert_empty convention_deps('DefaultWarehouseAllocationService')
  end

  def test_skips_static_fields
    cid = insert_class('DefaultWarehouseAllocationService')
    insert_field(cid, 'logger', 'Logger', modifiers: 'private static final')
    insert_method(cid, 'setLogger', return_type: 'void')

    assert_empty convention_deps('DefaultWarehouseAllocationService')
  end

  def test_skips_final_fields
    cid = insert_class('DefaultWarehouseAllocationService')
    insert_field(cid, 'maxRetries', 'int', modifiers: 'private final')
    insert_method(cid, 'setMaxRetries', return_type: 'void')

    assert_empty convention_deps('DefaultWarehouseAllocationService')
  end

  def test_detects_multiple_convention_fields
    cid = insert_class('DefaultWarehouseAllocationService')
    insert_field(cid, 'availabilityService', 'AvailabilityService')
    insert_field(cid, 'modelService', 'ModelService')
    insert_method(cid, 'setAvailabilityService', return_type: 'void')
    insert_method(cid, 'setModelService', return_type: 'void')

    results = convention_deps('DefaultWarehouseAllocationService')

    assert_equal 2, results.size
    names = results.map { |r| r['dependency_name'] }
    assert_includes names, 'availabilityService'
    assert_includes names, 'modelService'
  end

  def test_matches_by_simple_name
    cid = insert_class('com.example.warehouse.DefaultWarehouseAllocationService')
    # simple_name is set to last segment in insert_class helper
    insert_field(cid, 'availabilityService', 'AvailabilityService')
    insert_method(cid, 'setAvailabilityService', return_type: 'void')

    results = convention_deps('DefaultWarehouseAllocationService')

    assert_equal 1, results.size
  end

  # --- Mode 2: find_convention_setter_injections_of_type ---

  def test_finds_classes_injecting_type_via_convention
    cid = insert_class('DefaultWarehouseAllocationService')
    insert_field(cid, 'availabilityService', 'AvailabilityService')
    insert_method(cid, 'setAvailabilityService', return_type: 'void')

    results = convention_injectors('AvailabilityService')

    assert_equal 1, results.size
    assert_equal 'DefaultWarehouseAllocationService', results.first['class_name']
    assert_equal 'availabilityService', results.first['dependency_name']
    assert_equal 'AvailabilityService', results.first['dependency_type']
  end

  def test_mode2_skips_annotated_fields
    cid = insert_class('DefaultWarehouseAllocationService')
    fid = insert_field(cid, 'availabilityService', 'AvailabilityService')
    insert_annotation('field', fid, 'Autowired')
    insert_method(cid, 'setAvailabilityService', return_type: 'void')

    assert_empty convention_injectors('AvailabilityService')
  end

  def test_mode2_returns_multiple_classes
    cid1 = insert_class('ServiceA', extension: 'ext1')
    insert_field(cid1, 'modelService', 'ModelService')
    insert_method(cid1, 'setModelService', return_type: 'void')

    cid2 = insert_class('ServiceB', extension: 'ext2')
    insert_field(cid2, 'modelService', 'ModelService')
    insert_method(cid2, 'setModelService', return_type: 'void')

    results = convention_injectors('ModelService')

    assert_equal 2, results.size
    class_names = results.map { |r| r['class_name'] }
    assert_includes class_names, 'ServiceA'
    assert_includes class_names, 'ServiceB'
  end
end
