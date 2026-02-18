# Command Cheatsheet

## One-Time Setup

```bash
# 1. Install dependencies
bundle install
gem install mcp

# 2. Make executable
chmod +x bin/sap-commerce-mcp

# 3. Optional: Install tree-sitter grammar (recommended)
git clone https://github.com/tree-sitter/tree-sitter-java /tmp/tree-sitter-java
cd /tmp/tree-sitter-java
cc -shared -o libtree-sitter-java.dylib -I src src/parser.c src/scanner.c -fPIC
mkdir -p ~/.sap-commerce-mcp/grammars
cp libtree-sitter-java.dylib ~/.sap-commerce-mcp/grammars/

# 4. Configure Claude Code
# Edit ~/.config/claude/mcp.json (see MCP Configuration section below)
# The config handles the environment variable - you don't run commands manually

# 5. Restart Claude Code
# Index builds automatically when Claude Code first uses the server
```

## MCP Configuration (Production Use)

**This is how you actually use the server - Claude Code handles everything:**

### Standard Mode (Regex Parser)
```json
{
  "mcpServers": {
    "sap-commerce": {
      "command": "/FULL/PATH/sap-commerce-mcp/bin/sap-commerce-mcp",
      "args": ["/FULL/PATH/hybris"]
    }
  }
}
```

### Enhanced Mode (Tree-Sitter Parser - Recommended)
```json
{
  "mcpServers": {
    "sap-commerce": {
      "command": "/FULL/PATH/sap-commerce-mcp/bin/sap-commerce-mcp",
      "args": ["/FULL/PATH/hybris"],
      "env": {
        "SAP_MCP_USE_TREE_SITTER": "true"
      }
    }
  }
}
```

**Important:**
- Use full absolute paths
- Restart Claude Code after changes
- **The env var in the config is all you need** - Claude Code passes it automatically
- You don't run commands manually after this is set up

## Daily Commands (Via Claude)

```
# Find classes
"Find ProductService"
"Find all *Facade classes"
"Find @Controller classes in commercefacades"

# Get signatures
"What methods does DefaultCartService have?"
"Show me the CartService interface"

# Find implementations
"Show implementations of ProductService"
"What classes extend AbstractProductService?"

# Find usages
"Where is ProductModel used?"
"What files import CartService?"

# Dependency analysis ⭐ ENHANCED - ALL injection types
"What services does DefaultCheckoutFacade depend on?"
"What classes inject CheckoutService?"
"Show me all dependencies of DefaultCartFacade"
"Find all classes that use ProductService"
"What Spring beans does checkoutFacade depend on?"

# Spring beans
"Find Spring beans for cart"
"Show me all *Service beans"

# Maintenance
"Rebuild the index"
"Show index statistics"
```

## Maintenance Commands (Terminal)

```bash
# View logs
tail -f ~/.sap-commerce-mcp/logs/audit-$(date +%Y-%m-%d).log

# Check index
ls -lh ~/.sap-commerce-mcp/indexes/
sqlite3 ~/.sap-commerce-mcp/indexes/*.db "SELECT COUNT(*) FROM classes;"

# Rebuild index (clean start)
rm ~/.sap-commerce-mcp/indexes/*.db
# Then restart Claude Code

# View recent logs
tail -50 ~/.sap-commerce-mcp/logs/audit-*.log

# Search logs
grep "search_classes" ~/.sap-commerce-mcp/logs/audit-*.log

# Clean old logs (30+ days)
find ~/.sap-commerce-mcp/logs/ -name "audit-*.log" -mtime +30 -delete
```

## Troubleshooting Commands

```bash
# Check Ruby version
ruby --version  # Need 3.0+

# Check syntax
ruby -c bin/sap-commerce-mcp

# Verify dependencies
bundle check

# Reinstall
bundle install

# Validate JSON config
python3 -m json.tool ~/.config/claude/mcp.json

# Check index exists
ls ~/.sap-commerce-mcp/indexes/*.db

# Check log for errors
grep -i error ~/.sap-commerce-mcp/logs/audit-*.log

# Tree-sitter specific
# Check grammar exists
ls -l ~/.sap-commerce-mcp/grammars/libtree-sitter-java.dylib

# Check if tree-sitter features are in the index
# (Many results = tree-sitter mode was used)
sqlite3 ~/.sap-commerce-mcp/indexes/*.db \
  "SELECT COUNT(*) FROM fields WHERE generic_type IS NOT NULL;"

# Check inner classes (should be > 0 if tree-sitter was used)
sqlite3 ~/.sap-commerce-mcp/indexes/*.db \
  "SELECT COUNT(*) FROM classes WHERE is_inner_class = 1;"
```

## Quick Tests

```bash
# Test 1: Installation
ruby --version && bundle check

# Test 2: Syntax
ruby -c bin/sap-commerce-mcp

# Test 3: Index exists
ls -lh ~/.sap-commerce-mcp/indexes/

# Test 4: Config valid
python3 -m json.tool ~/.config/claude/mcp.json

# Test 5: Recent activity
tail -5 ~/.sap-commerce-mcp/logs/audit-*.log
```

## File Locations

```bash
# Index database (enhanced schema)
~/.sap-commerce-mcp/indexes/*.db
# Dependency tracking: bean_dependencies, constructor_params
# Tree-sitter: generic_signature, is_inner_class, parameters (JSON)

# Tree-sitter grammar (optional)
~/.sap-commerce-mcp/grammars/libtree-sitter-java.dylib  # macOS
~/.sap-commerce-mcp/grammars/libtree-sitter-java.so     # Linux

# Audit logs
~/.sap-commerce-mcp/logs/audit-YYYY-MM-DD.log

# Claude config
~/.config/claude/mcp.json

# Project files
/path/to/sap-commerce-mcp/
```

## Common Workflows

### Weekly Maintenance
```bash
# Option 1: Via Claude
"Rebuild the index"

# Option 2: Clean rebuild
rm ~/.sap-commerce-mcp/indexes/*.db
# Restart Claude Code
```

### After Hybris Upgrade
```bash
# Clean rebuild
rm ~/.sap-commerce-mcp/indexes/*.db
# Restart Claude Code
# Index rebuilds on first use
```

### Debugging Issues
```bash
# 1. Check logs
tail -50 ~/.sap-commerce-mcp/logs/audit-*.log

# 2. Verify index
sqlite3 ~/.sap-commerce-mcp/indexes/*.db "SELECT COUNT(*) FROM classes;"

# 3. Check config
cat ~/.config/claude/mcp.json

# 4. Validate JSON
python3 -m json.tool ~/.config/claude/mcp.json

# 5. Check tree-sitter (if using enhanced mode)
ls ~/.sap-commerce-mcp/grammars/
echo $SAP_MCP_USE_TREE_SITTER  # Should show 'true' if in env

# 6. Clean restart
rm -rf ~/.sap-commerce-mcp/
# Restart Claude Code
```

### Testing Tree-Sitter (Manual Testing Only)
```bash
# ONLY for manual testing - not needed if using via Claude Code

# Build index with tree-sitter manually
SAP_MCP_USE_TREE_SITTER=true bin/sap-commerce-mcp /path/to/hybris

# Verify features work
sqlite3 ~/.sap-commerce-mcp/indexes/*.db << EOF
.mode column
.headers on
SELECT 'Generic Types' as Feature, COUNT(*) as Count
FROM fields WHERE generic_type IS NOT NULL
UNION
SELECT 'Inner Classes', COUNT(*)
FROM classes WHERE is_inner_class = 1
UNION
SELECT 'Annotations w/Params', COUNT(*)
FROM annotations WHERE parameters IS NOT NULL;
EOF

# Expected results:
# Generic Types: 100+ (varies by project)
# Inner Classes: 10+ (varies by project)
# Annotations w/Params: 50+ (varies by project)

# For production use:
# Just set "SAP_MCP_USE_TREE_SITTER": "true" in ~/.config/claude/mcp.json
# Then restart Claude Code - it handles everything automatically
```

## Performance Monitoring

```bash
# Count total tool calls
grep -c "tool" ~/.sap-commerce-mcp/logs/audit-*.log

# Average response time
grep "processing_time_ms" ~/.sap-commerce-mcp/logs/audit-*.log | \
  jq '.output.processing_time_ms' | \
  awk '{sum+=$1; count++} END {print "Average:", sum/count, "ms"}'

# Most used tools
grep "tool" ~/.sap-commerce-mcp/logs/audit-*.log | \
  jq -r '.tool' | \
  sort | uniq -c | sort -rn

# Index size
du -h ~/.sap-commerce-mcp/indexes/
```

## Database Queries

```bash
# Basic stats
sqlite3 ~/.sap-commerce-mcp/indexes/*.db << EOF
SELECT 'Classes', COUNT(*) FROM classes
UNION SELECT 'Methods', COUNT(*) FROM methods
UNION SELECT 'Fields', COUNT(*) FROM fields
UNION SELECT 'Annotations', COUNT(*) FROM annotations;
EOF

# Dependency tracking stats
sqlite3 ~/.sap-commerce-mcp/indexes/*.db << EOF
SELECT 'Constructor Params', COUNT(*) FROM constructor_params
UNION SELECT 'Bean Dependencies', COUNT(*) FROM bean_dependencies;
EOF

# Tree-sitter feature stats
sqlite3 ~/.sap-commerce-mcp/indexes/*.db << EOF
SELECT 'Generic Fields', COUNT(*) FROM fields WHERE generic_type IS NOT NULL
UNION SELECT 'Inner Classes', COUNT(*) FROM classes WHERE is_inner_class = 1
UNION SELECT 'Annotations with Params', COUNT(*) FROM annotations WHERE parameters IS NOT NULL;
EOF

# Sample generic types
sqlite3 ~/.sap-commerce-mcp/indexes/*.db \
  "SELECT name, generic_type FROM fields WHERE generic_type IS NOT NULL LIMIT 5;"

# Sample inner classes
sqlite3 ~/.sap-commerce-mcp/indexes/*.db \
  "SELECT c1.name as inner, c2.name as parent
   FROM classes c1
   LEFT JOIN classes c2 ON c1.parent_class_id = c2.id
   WHERE c1.is_inner_class = 1 LIMIT 5;"

# Sample annotation parameters
sqlite3 ~/.sap-commerce-mcp/indexes/*.db \
  "SELECT annotation_name, parameters FROM annotations
   WHERE parameters IS NOT NULL LIMIT 3;"
```

## Manual Testing Aliases (Optional)

**These are ONLY for manual testing/debugging, NOT for production use via Claude Code:**

```bash
# Add to ~/.bashrc or ~/.zshrc

# Manual testing (not needed for Claude Code)
alias sap-mcp-test='/path/to/sap-commerce-mcp/bin/sap-commerce-mcp'
alias sap-mcp-test-ts='SAP_MCP_USE_TREE_SITTER=true /path/to/sap-commerce-mcp/bin/sap-commerce-mcp'

# Utilities
alias sap-logs='tail -f ~/.sap-commerce-mcp/logs/audit-$(date +%Y-%m-%d).log'
alias sap-stats='sqlite3 ~/.sap-commerce-mcp/indexes/*.db "SELECT COUNT(*) FROM classes;"'
alias sap-rebuild='rm ~/.sap-commerce-mcp/indexes/*.db'
alias sap-grammar='ls -l ~/.sap-commerce-mcp/grammars/'

# Usage (manual testing only)
sap-mcp-test /path/to/hybris     # Test standard mode
sap-mcp-test-ts /path/to/hybris  # Test tree-sitter mode
sap-logs                         # Watch logs
sap-stats                        # Quick stats
sap-rebuild                      # Clean rebuild (then restart Claude Code)
sap-grammar                      # Check grammar installation

# For production: Just configure ~/.config/claude/mcp.json
# Claude Code handles everything automatically
```

## Parser Comparison

```bash
# Quick check: Which parser features are working?

# Generic types (tree-sitter only)
echo "Generic types:"
sqlite3 ~/.sap-commerce-mcp/indexes/*.db \
  "SELECT COUNT(*) FROM fields WHERE generic_type IS NOT NULL;"
# Many results = tree-sitter, Few/none = regex

# Inner classes (tree-sitter only)
echo "Inner classes:"
sqlite3 ~/.sap-commerce-mcp/indexes/*.db \
  "SELECT COUNT(*) FROM classes WHERE is_inner_class = 1;"
# > 0 = tree-sitter, 0 = regex

# Annotation parameters (tree-sitter only)
echo "Annotations with params:"
sqlite3 ~/.sap-commerce-mcp/indexes/*.db \
  "SELECT COUNT(*) FROM annotations WHERE parameters IS NOT NULL;"
# Many results = tree-sitter, Few/none = regex
```

---

**Need more help?** See [SETUP_GUIDE.md](SETUP_GUIDE.md) or [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
