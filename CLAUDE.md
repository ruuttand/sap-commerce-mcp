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
   - Schema: classes, methods, fields, annotations, spring_beans, imports, interfaces
   - Build-once philosophy: core hybris code rarely changes
   - Indexes on first run, reuses on subsequent runs
   - **Field-level dependency tracking**: Captures Spring injection annotations (@Autowired, @Resource, @Inject) on class fields

3. **Parsing Layer** (`lib/sap_commerce_mcp/parser/`)
   - `SapCommerceParser`: Extension discovery, Spring XML parsing
   - `JavaParser`: Java source code parsing (classes, methods, annotations)
   - Understands SAP Commerce structure (extensions, ItemModels, etc.)

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
# Direct execution (for testing)
bin/sap-commerce-mcp /path/to/hybris

# Production usage (via Claude Code MCP config)
claude mcp add sap-commerce --scope user -- /full/path/bin/sap-commerce-mcp /full/path/hybris
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

### No Test Suite
This project currently has no tests (no spec/ or test/ directories, no Rakefile).

## Important Implementation Details

### Database Schema Design
- **classes table**: Indexed on name, simple_name, extension, type
- **class_interfaces table**: Many-to-many relationship for implemented interfaces
- **methods table**: Foreign key to classes, includes signature and return_type
- **fields table**: Foreign key to classes, tracks field name, type, and modifiers (NEW)
- **annotations table**: Polymorphic (target_type + target_id) for class/method/field annotations
  - Supports target_type: 'class', 'method', 'field'
  - Enables field-level dependency tracking for Spring injection (@Autowired, @Resource, @Inject, @Qualifier)
- **spring_beans table**: Separate from classes, linked by class_name
- **imports table**: Tracks all import statements for usage analysis

**Key Feature: Field-Level Dependency Tracking**
The fields table combined with field annotations enables powerful dependency analysis:
- Find all services injected into a specific class
- Find all classes that depend on a specific service
- Understand Spring DI relationships at the field level
- Critical for SAP Commerce where field injection is the primary DI pattern

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
Find all classes that implement an interface or extend a class.

### 4. FindUsages
Find all files that import or use a specific class.

### 5. SearchAnnotations
Find all classes or methods with a specific annotation (e.g., @Controller, @Service).

### 6. GetSpringBeans
Search Spring bean definitions by bean ID pattern or extension.

### 7. FindInjectedDependencies (NEW)
**Powerful field-level dependency analysis tool**

Find Spring dependency injection relationships through field-level annotations:
- Find all services injected INTO a specific class
- Find all classes that inject a specific service type
- Filter by annotation type (@Autowired, @Resource, @Inject)
- Example queries:
  - "What services does DefaultCheckoutFacade depend on?"
  - "Find all classes that inject CheckoutService"
  - "Show me all @Resource annotated fields in my custom extension"

This tool is critical for understanding the dependency graph in SAP Commerce projects where field injection is the primary DI pattern.

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
