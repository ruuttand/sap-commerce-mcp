# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an MCP (Model Context Protocol) server for SAP Commerce Cloud projects, built with the official Ruby SDK from Anthropic/Shopify. It enables Claude Code to efficiently navigate large SAP Commerce codebases with 60-80% token reduction through intelligent code indexing and search capabilities.

## Core Architecture

### Three-Layer Design

1. **MCP Server Layer** (`bin/sap-commerce-mcp`)
   - Entry point that initializes the MCP server using official Ruby SDK
   - Manages stdio transport for communication with Claude Code
   - Configures server context (indexer, audit logger, project path)
   - Registers 9 MCP tools as classes (not instances)

2. **Indexing Layer** (`lib/sap_commerce_mcp/indexer.rb`)
   - SQLite-based index stored in `~/.sap-commerce-mcp/indexes/`
   - Hash-based naming: `{MD5(project_path)[0..8]}.db`
   - Schema: classes, methods, fields, annotations, spring_beans, bean_dependencies, constructor_params, imports, interfaces
   - Build-once philosophy: core hybris code rarely changes
   - Indexes on first run, reuses on subsequent runs
   - **Comprehensive dependency tracking**: Captures ALL Spring injection patterns:
     - Field injection (@Autowired, @Resource, @Inject on fields)
     - Constructor injection (@Autowired on constructors + parameters)
     - Method injection (@Autowired on setter methods)
     - Spring XML property/constructor-arg refs

3. **Parsing Layer** (`lib/sap_commerce_mcp/parser/`)
   - `SapCommerceParser`: Extension discovery, Spring XML parsing
   - **Two Parser Options**:
     - `TreeSitterJavaParser`: Tree-sitter AST parser (default, robust universal type extraction)
     - `JavaParser`: Regex-based parser (fallback, opt-in via `SAP_MCP_USE_REGEX_PARSER=true`)
   - Understands SAP Commerce structure (extensions, ItemModels, etc.)

### Tree-Sitter Parser (Default, Enhanced)

**Now the default parser** - automatically used if tree-sitter gem and grammar are available.
**Opt-out**: Use `SAP_MCP_USE_REGEX_PARSER=true` to explicitly use regex parser instead.

**Advantages over regex parser**:
1. **Generic Type Extraction**: Full support for complex generics
   - Classes: `class ProductDao<T extends Model>`
   - Fields: `Map<String, List<ProductModel>> cache`
   - Methods: `<R extends Result> R findById(String id)`

2. **Inner Classes**: Complete inner/nested class extraction
   - Static inner classes
   - Private inner classes
   - Deeply nested classes (unlimited depth)
   - Tracks parent-child relationships via `parent_class_id`

3. **Complex Annotations**: Multi-line annotations with full parameters
   - `@RequestMapping(value = "/api", method = RequestMethod.GET)`
   - Parameters stored as JSON for structured querying
   - Handles nested parentheses and arrays

4. **Better Edge Case Handling**: Proper AST parsing vs regex patterns
   - Comments don't break parsing
   - Multi-line constructs handled correctly
   - Nested generics fully supported

**Requirements** (automatically checked, falls back to regex parser if missing):
- Grammar file at `~/.sap-commerce-mcp/grammars/libtree-sitter-java.dylib` (macOS) or `.so` (Linux)
- Automatically discovered by grammar loader
- Download from: https://github.com/tree-sitter/tree-sitter-java/releases
- If grammar not found, server will automatically fall back to regex parser with a warning

### Key Design Patterns

**Extension Discovery**: Searches multiple path patterns to find all SAP Commerce extensions:
- `bin/custom/*`, `hybris/bin/custom/*`
- `bin/ext-*/*`, `bin/platform/ext/*`
- `bin/modules/*/*`
- Prefers `extensioninfo.xml` discovery, falls back to directory patterns

**ItemModel Detection**: Identifies SAP Commerce data models by:
- Class name ends with "Model"
- Parent class contains "ItemModel"

**Tool Pattern**: All tools inherit from `MCP::Tool` and implement:
- `title`, `description`, `input_schema` (declarative)
- `call` class method that receives `server_context`
- Returns `MCP::Tool::Response` with text content
- Wrapped in begin/rescue for audit logging

## Development Commands

### Installation
```bash
bundle install
gem install mcp
chmod +x bin/sap-commerce-mcp
```

### Testing Installation
```bash
ruby -c bin/sap-commerce-mcp  # Syntax check
```

### Running the Server
```bash
# Direct execution with explicit path (for testing)
bin/sap-commerce-mcp /path/to/hybris

# Using environment variable
export SAP_COMMERCE_PROJECT_PATH="/path/to/hybris"
bin/sap-commerce-mcp

# Using current directory (fallback)
cd /path/to/hybris && bin/sap-commerce-mcp

# Production usage (via Claude Code MCP config)
claude mcp add sap-commerce --scope user -- /full/path/bin/sap-commerce-mcp /full/path/hybris

# Or with environment variable in MCP config
claude mcp add sap-commerce --scope user --env SAP_COMMERCE_PROJECT_PATH=/path/to/hybris -- /full/path/bin/sap-commerce-mcp
```

### Index Management
```bash
# View index stats
sqlite3 ~/.sap-commerce-mcp/indexes/*.db "SELECT COUNT(*) FROM classes;"

# Rebuild index (delete and restart server)
rm ~/.sap-commerce-mcp/indexes/*.db

# View audit logs
tail -f ~/.sap-commerce-mcp/logs/audit-$(date +%Y-%m-%d).log
```

### Test Suite
Tests are in `test/unit/` and `test/fixtures/`:
```bash
# Run tree-sitter parser tests
bundle exec ruby test/unit/tree_sitter_java_parser_test.rb

# Run all tests in test/unit/
bundle exec ruby test/unit/*.rb
```

Test fixtures demonstrate Phase 1 features:
- `GenericClass.java`: Generic types and methods
- `InnerClassExample.java`: Nested inner classes
- `ComplexAnnotations.java`: Multi-line annotations with parameters

## Important Implementation Details

### Database Schema Design
- **classes table**: Indexed on name, simple_name, extension, type
  - `parent_class_id`: Foreign key for inner classes (tree-sitter only)
  - `generic_signature`: Generic type parameters like `<T extends Model>` (tree-sitter only)
  - `is_inner_class`: Boolean flag for inner classes (tree-sitter only)
- **class_interfaces table**: Many-to-many relationship for implemented interfaces
- **methods table**: Foreign key to classes, includes signature and return_type
  - `generic_signature`: Method-level generics like `<R extends Result>` (tree-sitter only)
- **fields table**: Foreign key to classes, tracks field name, type, and modifiers
  - `generic_type`: Full generic type like `Map<String, List<Product>>` (tree-sitter only)
- **constructor_params table**: Tracks constructor parameters for injection analysis (param_index, param_name, param_type)
- **annotations table**: Polymorphic (target_type + target_id) for class/method/field/constructor/constructor_param annotations
  - `parameters`: JSON-encoded annotation parameters (tree-sitter only)
  - Supports target_type: 'class', 'method', 'field', 'constructor', 'constructor_param'
  - Enables comprehensive dependency tracking for all Spring injection patterns
- **spring_beans table**: Separate from classes, linked by class_name
- **bean_dependencies table**: Tracks Spring XML property/constructor-arg refs (dependency_type, dependency_name, ref_bean_id, ref_class)
- **imports table**: Tracks all import statements for usage analysis

**Key Feature: Comprehensive Dependency Tracking**
The combination of fields, constructor_params, methods, and bean_dependencies tables with polymorphic annotations enables complete dependency graph analysis:
- Find all dependencies of a class (field + constructor + method + XML)
- Find all classes that depend on a specific service (reverse lookup)
- Understand Spring DI relationships across all injection patterns
- Critical for SAP Commerce which uses all injection patterns extensively

### Tool Execution Flow
1. Claude Code sends MCP request via stdio
2. SDK routes to appropriate tool's `call` class method
3. Tool receives `server_context` hash with indexer/audit_logger
4. Tool uses `Search::QueryProcessor` to query SQLite
5. Results formatted via `Search::ResultFormatter`
6. Audit logger records request/response/duration
7. Tool returns `MCP::Tool::Response` to SDK

### File Structure Conventions
- Tools go in `lib/sap_commerce_mcp/tools/`
- Each major tool has its own file (search_classes.rb, get_class_signature.rb, etc.)
- Helper tools combined in `remaining_tools.rb`
- Parsers in `lib/sap_commerce_mcp/parser/`
- Search logic in `lib/sap_commerce_mcp/search/`
- Main module file (`lib/sap_commerce_mcp.rb`) requires all components

### Audit Logging Pattern
Every tool execution is logged with:
- Timestamp
- Tool name
- Input parameters
- Output (result_count, processing_time_ms)
- Errors if any

Logs stored daily: `~/.sap-commerce-mcp/logs/audit-YYYY-MM-DD.log`

## SAP Commerce-Specific Knowledge

### Extension Structure
Extensions are discovered by looking for:
1. `extensioninfo.xml` (primary)
2. Typical directories: `src/`, `resources/`, `web/src/`, `testsrc/`, `gensrc/`

### Source Directories Scanned
- `src/` - Main source code
- `web/src/` - Web application source
- `testsrc/` - Test source
- `gensrc/` - Generated source (from items.xml)

### Spring Bean Discovery
Spring XML files matched by pattern: `resources/**/*-spring.xml`

### Path Pattern Recognition
Extension names extracted from paths like:
- `.../bin/custom/myextension/src/...`
- `.../bin/ext-commerce/commerceservices/src/...`

## Data Locations

- **Index databases**: `~/.sap-commerce-mcp/indexes/{hash}.db`
- **Audit logs**: `~/.sap-commerce-mcp/logs/audit-{date}.log`
- **Configuration**: Managed via `claude mcp` CLI, not in this repo

## Dependencies

From Gemfile:
- `mcp` - Official MCP SDK (from GitHub)
- `sqlite3` - Database for indexing
- `concurrent-ruby` - Thread-safe operations
- `nokogiri` - XML parsing (Spring beans)
- `logger` - Explicit requirement for Ruby 3.5+
- `ruby_tree_sitter` - Tree-sitter parser (optional, for enhanced parsing)
- Development: `minitest`, `minitest-reporters`, `rake`, `debug`

## Performance Characteristics

- **Indexing speed**: 300-500 classes/second
- **Search speed**: < 100ms typical
- **Index size**: ~50MB for 10K classes
- **Memory usage**: ~100MB runtime
- **Token savings**: 60-80% for code discovery tasks

## Available MCP Tools

### 1. SearchClasses
Search for Java classes by name pattern, with filters for extension, type, and annotations.

### 2. GetClassSignature
Get method signatures and structure of a specific class without loading the full file.

### 3. FindImplementations
Find all classes that implement an interface or extend a class. Results include a `relationship` field indicating whether each class:
- **extends** the searched class (inheritance via parent_class)
- **implements** the searched interface (via class_interfaces table)

This distinction helps understand whether results are subclasses (inheritance) or interface implementations.

### 4. FindUsages
Find all files that import a specific class by searching the imports table.

Accepts both fully qualified names (e.g., `de.hybris.platform.core.model.product.ProductModel`) and simple names (e.g., `ProductModel`). Simple names may match multiple imports if ambiguous.

### 5. SearchAnnotations
Find all classes or methods with a specific annotation (e.g., @Controller, @Service).

### 6. GetSpringBeans
Search Spring bean definitions by bean ID pattern or extension.

### 7. FindInjectedDependencies
**Comprehensive dependency analysis tool tracking ALL Spring injection patterns**

Find Spring dependency injection relationships across all injection types:
- **Field injection**: @Autowired/@Resource/@Inject on fields
- **Constructor injection**: @Autowired on constructors + parameters
- **Method injection**: @Autowired on setter methods
- **Spring XML**: property/constructor-arg refs in Spring XML files

Two modes:
- Find all dependencies OF a class: "What services does DefaultCheckoutFacade depend on?"
- Find all classes INJECTING a type: "What classes inject CheckoutService?"

Features:
- Filter by annotation type (@Autowired, @Resource, @Inject)
- Shows injection type (Field/Constructor/Method/Spring XML)
- Includes annotations, qualifiers, and XML configuration
- Complete dependency graph visibility

This tool is critical for understanding the complete dependency graph in SAP Commerce projects, which extensively use all injection patterns.

### 8. RebuildIndex
Force rebuild of the code index (useful after major codebase changes).

### 9. GetIndexStats
Get statistics about the current index (classes, methods, fields, extensions, etc.).

## Adding New Tools

1. Create file in `lib/sap_commerce_mcp/tools/{tool_name}.rb`
2. Define class inheriting from `MCP::Tool`
3. Set `title`, `description`, `input_schema`
4. Implement `call` class method with `server_context:`
5. Add audit logging (start_time, log_request)
6. Return `MCP::Tool::Response.new([{type: 'text', text: ...}])`
7. Add to tools array in `bin/sap-commerce-mcp`
8. Require in `lib/sap_commerce_mcp.rb`

## Useful Database Queries (Tree-Sitter Enhanced)

When using tree-sitter parser (`SAP_MCP_USE_TREE_SITTER=true`), these queries unlock additional insights:

### Find All Inner Classes
```sql
SELECT c.name, c.simple_name, p.name as parent_class
FROM classes c
LEFT JOIN classes p ON c.parent_class_id = p.id
WHERE c.is_inner_class = 1;
```

### Find Classes with Generic Type Parameters
```sql
SELECT name, generic_signature
FROM classes
WHERE generic_signature IS NOT NULL
ORDER BY extension, name;
```

### Find Fields with Generic Types (e.g., Collections)
```sql
SELECT c.name as class_name, f.name as field_name, f.generic_type
FROM fields f
JOIN classes c ON f.class_id = c.id
WHERE f.generic_type LIKE '%List%'
   OR f.generic_type LIKE '%Map%'
   OR f.generic_type LIKE '%Set%';
```

### Find Generic Methods
```sql
SELECT c.name as class_name, m.name as method_name, 
       m.generic_signature, m.return_type
FROM methods m
JOIN classes c ON m.class_id = c.id
WHERE m.generic_signature IS NOT NULL;
```

### Find Annotations with Complex Parameters
```sql
SELECT c.name as class_name, a.annotation_name, a.parameters
FROM annotations a
JOIN classes c ON a.target_type = 'class' AND a.target_id = c.id
WHERE a.parameters IS NOT NULL;
```

### Find Spring @RequestMapping Annotations
```sql
SELECT c.name, a.parameters
FROM annotations a
JOIN classes c ON a.target_type = 'class' AND a.target_id = c.id
WHERE a.annotation_name = 'RequestMapping'
  AND a.parameters IS NOT NULL;
```

### Find @Autowired Fields with @Qualifier
```sql
SELECT c.name as class_name, f.name as field_name, 
       a.annotation_name, a.parameters
FROM fields f
JOIN classes c ON f.class_id = c.id
JOIN annotations a ON a.target_type = 'field' AND a.target_id = f.id
WHERE a.annotation_name IN ('Autowired', 'Qualifier')
ORDER BY c.name, f.name;
```

### Find Nested Inner Classes (depth > 1)
```sql
WITH RECURSIVE class_hierarchy AS (
  SELECT id, name, parent_class_id, 1 as depth
  FROM classes
  WHERE is_inner_class = 1 AND parent_class_id IS NOT NULL
  
  UNION ALL
  
  SELECT c.id, c.name, c.parent_class_id, ch.depth + 1
  FROM classes c
  JOIN class_hierarchy ch ON c.parent_class_id = ch.id
)
SELECT name, depth
FROM class_hierarchy
WHERE depth > 1
ORDER BY depth DESC, name;
```

## Tree-Sitter vs Regex Parser Comparison

| Feature | Regex Parser | Tree-Sitter Parser |
|---------|-------------|-------------------|
| **Status** | Fallback/legacy | ✅ **Default** |
| **Basic Classes** | ✅ Full support | ✅ Full support |
| **Methods** | ✅ Full support | ✅ Enhanced with generics |
| **Fields** | ✅ Full support | ✅ Universal type extraction |
| **Annotations** | ⚠️ Single-line only | ✅ Multi-line with parameters |
| **Generic Types** | ❌ Limited | ✅ Full support |
| **Inner Classes** | ❌ Not supported | ✅ Recursive extraction |
| **Array Types** | ✅ Basic | ✅ All dimensions |
| **Edge Cases** | ⚠️ Comments can break | ✅ AST-based, robust |
| **Type Discovery** | ⚠️ Enumeration needed | ✅ Pattern-based, future-proof |
| **Performance** | Fast | Slightly slower, more accurate |

**Current Default**: Tree-sitter parser with universal type extraction (automatically falls back to regex if unavailable).
**Opt-out**: Set `SAP_MCP_USE_REGEX_PARSER=true` to explicitly use regex parser.

