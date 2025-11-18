# Quick Reference Card

## Installation (One Time)

```bash
cd sap-commerce-mcp-sdk
bundle install
gem install mcp
chmod +x bin/sap-commerce-mcp
```

## First Run

```bash
bin/sap-commerce-mcp /path/to/hybris
# Wait for index build (30-120s)
# Server ready when you see: "Ready to receive MCP requests"
```

## Claude Code Configuration

**File:** `~/.config/claude/mcp.json`

```json
{
  "mcpServers": {
    "sap-commerce": {
      "command": "/FULL/PATH/sap-commerce-mcp-sdk/bin/sap-commerce-mcp",
      "args": ["/FULL/PATH/to/hybris"]
    }
  }
}
```

**Important:** Use full absolute paths, restart Claude Code after changes.

## Common Claude Questions

| What You Say | Tool Used | What Happens |
|--------------|-----------|--------------|
| "Find ProductService" | search_classes | Returns class locations < 50ms |
| "What methods does DefaultCartService have?" | get_class_signature | Returns signatures without loading file |
| "Show implementations of CartService" | find_implementations | Lists all implementing classes |
| "Where is ProductModel used?" | find_usages | Shows all imports/usages |
| "Find all @Controller classes" | search_annotations | Lists annotated classes |
| "Find cart-related Spring beans" | get_spring_beans | Searches bean definitions |
| "Rebuild the index" | rebuild_index | Rebuilds SQLite index |
| "Show index stats" | get_index_stats | Returns statistics |

## File Locations

```
~/.sap-commerce-mcp/
├── indexes/
│   └── abc123def.db          # SQLite index (50MB typical)
└── logs/
    └── audit-2025-11-07.log  # Daily audit logs
```

## Maintenance

### Check Logs
```bash
tail -f ~/.sap-commerce-mcp/logs/audit-$(date +%Y-%m-%d).log
```

### View Stats
```bash
# Ask Claude: "Show index statistics"
```

### Rebuild Index
```bash
# Option 1: Ask Claude: "Rebuild the index"
# Option 2: Delete and restart
rm ~/.sap-commerce-mcp/indexes/*.db
# Restart Claude Code
```

### Clean Start
```bash
rm -rf ~/.sap-commerce-mcp/
# Next Claude Code use will rebuild everything
```

## Troubleshooting

### Server Won't Start
```bash
# Check Ruby version
ruby --version  # Need 3.0+

# Reinstall dependencies
bundle install

# Check syntax
ruby -c bin/sap-commerce-mcp
```

### Claude Not Using MCP
```bash
# Validate JSON
python3 -m json.tool ~/.config/claude/mcp.json

# Check paths are absolute (no ~ or relative)
# Restart Claude Code completely
```

### No Search Results
```bash
# Check index
ls -lh ~/.sap-commerce-mcp/indexes/

# Rebuild
rm ~/.sap-commerce-mcp/indexes/*.db
# Restart Claude Code
```

## Development Workflow

### Monday (Once per week)
```
Rebuild index to catch team's changes from last week
```

### Daily Work
```
1. Ask Claude to find core hybris patterns
2. Create new services/facades based on patterns
3. Ask Claude to review PRs
4. No index rebuilds needed (core code stable)
```

### After Hybris Upgrade
```
Rebuild index for new hybris version
```

## Performance Benchmarks

| Operation | Time | Tokens |
|-----------|------|--------|
| search_classes | 30-100ms | 1-2K |
| get_class_signature | 20-50ms | 2-3K |
| find_implementations | 40-100ms | 1-2K |
| Traditional file loading | 5-30s | 50-150K |

**Token Savings:** 60-80% on discovery phase

## Support Checklist

If something's not working:

- [ ] Ruby 3.0+ installed?
- [ ] `bundle install` successful?
- [ ] Index built? (check `~/.sap-commerce-mcp/indexes/`)
- [ ] `mcp.json` has absolute paths?
- [ ] `mcp.json` valid JSON?
- [ ] Claude Code restarted after config change?
- [ ] Logs show tool calls? (tail the audit log)

## Quick Tests

### Test 1: Check Installation
```bash
ruby --version              # 3.0+
bundle exec ruby -c bin/sap-commerce-mcp  # Syntax OK
```

### Test 2: Check Index
```bash
ls -lh ~/.sap-commerce-mcp/indexes/  # Should see .db file
sqlite3 ~/.sap-commerce-mcp/indexes/*.db "SELECT COUNT(*) FROM classes;"
```

### Test 3: Check Config
```bash
cat ~/.config/claude/mcp.json
python3 -m json.tool ~/.config/claude/mcp.json
```

### Test 4: Check Logs
```bash
tail -20 ~/.sap-commerce-mcp/logs/audit-*.log
# Should see tool calls after using Claude
```

---

**Need more help?** See [SETUP_GUIDE.md](SETUP_GUIDE.md) for detailed instructions.
