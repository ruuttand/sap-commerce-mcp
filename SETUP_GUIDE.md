# SAP Commerce MCP Server - Complete Setup Guide

## Overview

This is a complete MCP (Model Context Protocol) server for SAP Commerce Cloud projects, built with the **official Ruby SDK** from Anthropic/Shopify. It enables Claude Code to efficiently navigate large SAP Commerce codebases with 60-80% token reduction.

## Prerequisites

- **Ruby 3.0+** (check with `ruby --version`)
- **SAP Commerce Cloud project** (hybris directory structure)
- **Claude Code** or compatible MCP client

---

## Phase 1: Installation (5 minutes)

### Step 1: Clone/Download the Project

```bash
cd ~/projects
# If you have this as a git repo:
git clone <your-repo> sap-commerce-mcp-sdk
cd sap-commerce-mcp-sdk

# Or if you have the files locally:
cd sap-commerce-mcp-sdk
```

### Step 2: Install Dependencies

```bash
  bundle install
  gem install mcp
```

**What this does:**
- Installs official MCP SDK from GitHub
- Installs SQLite3, Nokogiri, and other dependencies
- Sets up development/test gems

**Expected output:**
```
Fetching gem metadata from https://rubygems.org/
Fetching https://github.com/modelcontextprotocol/ruby-sdk
...
Bundle complete! 6 Gemfile dependencies, XX gems now installed.
```

### Step 3: Make Executable

```bash
chmod +x bin/sap-commerce-mcp
```

### Step 4: Test Installation

```bash
ruby -c bin/sap-commerce-mcp
```

**Expected:** `Syntax OK`

---

## Phase 2: Build Initial Index (10-15 minutes)

### Step 1: Navigate to Your SAP Commerce Project

```bash
cd /path/to/your/hybris
```

### Step 2: Run Initial Index

```bash
/path/to/sap-commerce-mcp-sdk/bin/sap-commerce-mcp /path/to/your/hybris
```

**Or create an alias:**
```bash
alias sap-mcp="/path/to/sap-commerce-mcp-sdk/bin/sap-commerce-mcp"
sap-mcp /path/to/hybris
```

**What happens:**
1. Server starts
2. Checks for existing index
3. If none exists, builds index automatically
4. Scans all extensions
5. Parses Java files
6. Extracts classes, methods, annotations
7. Stores in SQLite (~/.sap-commerce-mcp/indexes/)
8. Server ready for MCP requests

**Expected output:**
```
Starting SAP Commerce MCP Server...
Project: /Users/andree/projects/hybris
No index found. Building initial index...
Scanning extensions...
Found 25 extensions
Indexing files...
Index built: 8547 classes, 52341 methods
Index location: /Users/andree/.sap-commerce-mcp/indexes/abc123def.db
Audit logs: /Users/andree/.sap-commerce-mcp/logs
Registered 8 tools
Ready to receive MCP requests via stdio...
```

**Index Build Time:**
- Small project (< 2,000 classes): 10-20 seconds
- Medium project (5,000 classes): 30-60 seconds  
- Large project (10,000+ classes): 1-2 minutes

**Index Location:**
- `~/.sap-commerce-mcp/indexes/<hash>.db`
- `~/.sap-commerce-mcp/logs/audit-YYYY-MM-DD.log`

---

## Phase 3: Configure Claude Code (2 minutes)


### Step 1: Add Configuration to MCP

```
claude mcp add sap-commerce --scope user -- /full/path/sap-commerce-mcp/bin/sap-commerce-mcp /full/path/hybris
```

**Important:**
- Use **full absolute paths** (not `~` or relative paths)
- On macOS/Linux: `/full/path/sap-commerce-mcp/bin/sap-commerce-mcp`
- On Windows: `C:\full\path\sap-commerce-mcp\bin\sap-commerce-mcp`

configuration is added to ~/.claude.json

**Example:**
```json
{
  "mcpServers": {
    "sap-commerce": {
      "command": "/full/path/sap-commerce-mcp/bin/sap-commerce-mcp",
      "args": ["/full/path/hybris"],
      "env": {}
    }
  }
}
```

### Step 4: Restart Claude Code

**Completely restart Claude Code** to load the new MCP configuration.

---

## Phase 4: Verify It Works (2 minutes)

### Test 1: Simple Search

**In Claude Code, ask:**
```
Find ProductService in the hybris codebase
```

**What should happen:**
- Claude uses `search_classes` tool
- Returns results in < 100ms
- Shows: DefaultProductService, ProductService interface, etc.

### Test 2: Check Audit Logs

```bash
tail -f ~/.sap-commerce-mcp/logs/audit-$(date +%Y-%m-%d).log
```

**You should see:**
```json
{
  "timestamp": "2025-11-07T15:30:45.123Z",
  "tool": "search_classes",
  "input": {"query": "ProductService"},
  "output": {
    "result_count": 3,
    "processing_time_ms": 45.67
  }
}
```

### Test 3: Complex Query

**Ask Claude:**
```
Show me all @Controller classes in commercefacades extension
```

**Expected:**
- Uses `search_annotations` with filters
- Fast response (< 100ms)
- Lists all controllers

### Test 4: Get Method Signatures

**Ask Claude:**
```
What methods does DefaultCartService have?
```

**Expected:**
- Uses `get_class_signature` tool
- Returns method signatures without loading file
- Shows: addToCart(), removeFromCart(), etc.

---

## Phase 5: Daily Usage

### Rebuilding Index

**When to rebuild:**
- After hybris version upgrade
- Weekly/bi-weekly for team changes
- After major feature branch merge
- NOT after every file save

**How to rebuild:**

**Option 1: From Claude**
```
Rebuild the SAP Commerce index
```
- Claude uses `rebuild_index` tool with `force: true`

**Option 2: Command Line**
```bash
# You can't easily do this with the server running via stdio
# Instead, restart the server and it will auto-rebuild if needed
```

**Option 3: Delete and Restart**
```bash
rm ~/.sap-commerce-mcp/indexes/*.db
# Restart Claude Code
# Index rebuilds automatically on next use
```

### Checking Statistics

**Ask Claude:**
```
Show me the index statistics
```

**Claude uses** `get_index_stats` tool

**Returns:**
```json
{
  "last_indexed": "2025-11-07 10:30:00",
  "classes_count": 8547,
  "methods_count": 52341,
  "annotations_count": 12453,
  "beans_count": 892,
  "extensions_count": 25,
  "index_size_bytes": 52428800
}
```

### Viewing Audit Logs

```bash
# Today's logs
tail -50 ~/.sap-commerce-mcp/logs/audit-$(date +%Y-%m-%d).log

# All recent logs
ls -lh ~/.sap-commerce-mcp/logs/

# Search logs
grep "search_classes" ~/.sap-commerce-mcp/logs/audit-*.log
```

---

## Available MCP Tools

The server provides 9 tools that Claude Code can use automatically:

### 1. search_classes
Find Java classes by name or pattern
```
Claude: "Find all Service classes"
Tool: search_classes("*Service")
```

### 2. get_class_signature
Get method signatures without loading file
```
Claude: "What methods does DefaultProductService have?"
Tool: get_class_signature("...DefaultProductService")
```

### 3. find_implementations
Find all classes implementing interface
```
Claude: "Show implementations of CartService"
Tool: find_implementations("CartService")
```

### 4. find_usages
Find where a class is used
```
Claude: "Where is ProductModel used?"
Tool: find_usages("ProductModel")
```

### 5. find_injected_dependencies ⭐ ENHANCED
Find ALL dependency injection patterns
```
Claude: "What services does DefaultCheckoutFacade depend on?"
Tool: find_injected_dependencies(class_name: "DefaultCheckoutFacade")
→ Returns: Field, Constructor, Method, and XML injections

Claude: "What classes inject CheckoutService?"
Tool: find_injected_dependencies(injected_type: "CheckoutService")
→ Returns: All classes using CheckoutService (any injection type)
```

**Tracks:**
- Field injection (`@Autowired`, `@Resource`, `@Inject` on fields)
- Constructor injection (`@Autowired` on constructor + parameters)
- Method injection (`@Autowired` on setter methods)
- Spring XML property/constructor-arg refs

### 6. search_annotations
Find annotated classes/methods
```
Claude: "Find all @Controller classes"
Tool: search_annotations("Controller", target_type: "class")
```

### 7. get_spring_beans
Search Spring bean definitions
```
Claude: "Find Spring beans for cart"
Tool: get_spring_beans("*cart*")
```

### 8. rebuild_index
Rebuild the index
```
Claude: "Rebuild index"
Tool: rebuild_index(force: true)
```

### 9. get_index_stats
Get index statistics
```
Claude: "Show index stats"
Tool: get_index_stats()
```

---

## Troubleshooting

### Server Won't Start

**Error:** `bundle: command not found`
```bash
gem install bundler
bundle install
```

**Error:** `cannot load such file -- mcp`
```bash
bundle install
# Check Gemfile points to correct SDK repo
```

### Index Not Building

**Check paths:**
```bash
ls /path/to/hybris/bin/custom
# Should show your extensions
```

**Check permissions:**
```bash
ls -la ~/.sap-commerce-mcp/indexes/
# Should be writable
```

### Claude Not Using MCP

**Check config:**
```bash
cat ~/.config/claude/mcp.json
# Validate JSON syntax
python3 -m json.tool ~/.config/claude/mcp.json
```

**Check paths are absolute:**
```json
{
  "command": "/Users/andree/..."  // ✓ Good
  "command": "~/projects/..."     // ✗ Bad - use full path
}
```

**Restart Claude Code completely**

### Search Returns No Results

**Check index exists:**
```bash
ls -lh ~/.sap-commerce-mcp/indexes/
# Should show .db file
```

**Rebuild if needed:**
```bash
rm ~/.sap-commerce-mcp/indexes/*.db
# Restart - will rebuild
```

### Slow Performance

**Check index size:**
```bash
du -h ~/.sap-commerce-mcp/indexes/
# Should be 20-100MB
```

**If too large, optimize:**
```bash
sqlite3 ~/.sap-commerce-mcp/indexes/*.db "VACUUM;"
```

---

## Project Structure

```
sap-commerce-mcp-sdk/
├── bin/
│   └── sap-commerce-mcp          # Main executable (uses SDK)
├── lib/
│   └── sap_commerce_mcp/
│       ├── tools/                # 8 MCP tools (SDK-based)
│       │   ├── search_classes.rb
│       │   ├── get_class_signature.rb
│       │   └── ... (6 more)
│       ├── indexer.rb            # SQLite indexing
│       ├── parser/               # Java parsing
│       │   ├── java_parser.rb
│       │   └── sap_commerce_parser.rb
│       ├── search/               # Query processing
│       │   ├── query_processor.rb
│       │   └── result_formatter.rb
│       └── audit/                # Logging
│           └── logger.rb
├── Gemfile                       # With official MCP SDK
└── README.md
```

---

## Development

### Running Tests

```bash
bundle exec rake test
```

### Debugging

**Enable debug logging:**
```ruby
# In bin/sap-commerce-mcp, add:
require 'debug'

# Add breakpoints:
binding.break
```

**Check tool execution:**
```bash
# Tail logs while using
tail -f ~/.sap-commerce-mcp/logs/audit-*.log | jq .
```

---

## Performance Expectations

- **Indexing**: 300-500 classes/second
- **Search**: < 100ms typical
- **Index Size**: ~50MB for 10K classes
- **Memory**: ~100MB during operation
- **Token Savings**: 60-80% on discovery

---

## Next Steps

1. ✅ Install dependencies
2. ✅ Build index
3. ✅ Configure Claude Code
4. ✅ Test with simple queries
5. 🎯 Use in daily development:
   - Finding core hybris patterns
   - Extending services/facades
   - Reviewing PRs
   - Creating new features

---

## Support

**Check logs:**
```bash
ls -lh ~/.sap-commerce-mcp/logs/
tail -100 ~/.sap-commerce-mcp/logs/audit-*.log
```

**Check index:**
```bash
sqlite3 ~/.sap-commerce-mcp/indexes/*.db "SELECT COUNT(*) FROM classes;"
```

**Clean start:**
```bash
rm -rf ~/.sap-commerce-mcp/
# Restart - rebuilds everything
```

---

## Differences from Manual Implementation

### What Changed (Protocol Layer)
- ❌ Manual JSON-RPC handling → ✅ Official MCP SDK
- ❌ Custom tool definitions → ✅ MCP::Tool base class
- ❌ Manual stdio parsing → ✅ MCP::Transport::Stdio

### What Stayed the Same (Business Logic)
- ✅ SQLite indexer
- ✅ Java parser
- ✅ Search query processor
- ✅ Audit logger
- ✅ All 8 tools functionality

### Benefits of SDK
- ✅ Proper protocol compliance
- ✅ Better error handling
- ✅ Future-proof updates
- ✅ Less code to maintain

---

**You're ready to go! 🚀**

Start using Claude Code with your SAP Commerce project and experience the token savings!
