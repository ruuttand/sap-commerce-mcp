# Command Cheatsheet

## One-Time Setup

```bash
# 1. Install dependencies
bundle install
gem install mcp

# 2. Make executable
chmod +x bin/sap-commerce-mcp

# 3. First run (builds index)
bin/sap-commerce-mcp /path/to/hybris

# 4. Add MCP to Claude
claude mcp add sap-commerce --scope user -- /FULL/PATH/TO/sap-commerce-mcp/bin/sap-commerce-mcp /FULL/PATH/TO/your/hybris

# 5. Restart Claude Code
```

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
# Index database (enhanced with dependency tracking)
~/.sap-commerce-mcp/indexes/*.db
# New tables: bean_dependencies, constructor_params

# Audit logs
~/.sap-commerce-mcp/logs/audit-YYYY-MM-DD.log

# Claude config
~/.config/claude/mcp.json

# Project files
/path/to/sap-commerce-mcp-sdk/
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

# 5. Clean restart
rm -rf ~/.sap-commerce-mcp/
# Restart Claude Code
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

## Aliases (Optional)

```bash
# Add to ~/.bashrc or ~/.zshrc
alias sap-mcp='/path/to/sap-commerce-mcp-sdk/bin/sap-commerce-mcp'
alias sap-logs='tail -f ~/.sap-commerce-mcp/logs/audit-$(date +%Y-%m-%d).log'
alias sap-stats='sqlite3 ~/.sap-commerce-mcp/indexes/*.db "SELECT COUNT(*) FROM classes;"'
alias sap-rebuild='rm ~/.sap-commerce-mcp/indexes/*.db'

# Usage
sap-mcp /path/to/hybris
sap-logs
sap-stats
sap-rebuild
```

---

**Need more help?** See [SETUP_GUIDE.md](SETUP_GUIDE.md) or [QUICK_REFERENCE.md](QUICK_REFERENCE.md)
