# SAP Commerce MCP Server (Official SDK)

Fast code indexing and search for SAP Commerce Cloud projects using the official Model Context Protocol Ruby SDK.

## 🚀 Quick Start

```bash
# 1. Install
bundle install
gem install mcp

# 2. Index your project
bin/sap-commerce-mcp /path/to/hybris

# 3. Configure Claude Code (~/.config/claude/mcp.json)
claude mcp add sap-commerce --scope user -- /full/path/sap-commerce-mcp/bin/sap-commerce-mcp /full/path/hybris

# 4. Restart Claude Code and start using!
```

See **[SETUP_GUIDE.md](SETUP_GUIDE.md)** for complete instructions.

## ✨ Features

- ⚡ **60-80% Token Reduction** - Find code without loading files
- 🔍 **9 Search Tools** - Classes, methods, **comprehensive dependency tracking**, annotations, Spring beans
- 🎯 **ALL Injection Types** - Field, Constructor, Method, Spring XML dependencies
- 📊 **Complete Audit Trail** - Every operation logged
- 🏗️ **SAP Commerce-Aware** - ItemModels, extensions, hybris patterns, full DI tracking
- 🛠️ **Official SDK** - Built with Anthropic/Shopify Ruby SDK
- 💾 **SQLite Index** - Fast queries (< 100ms)

## 📋 Use Cases

### Finding Core Hybris Patterns
```
"How does hybris implement ProductService?"
→ search_classes, get_class_signature
→ Fast discovery of implementation pattern
```

### Extending Existing Code
```
"Extend DefaultCartService with custom discount logic"
→ Finds structure, shows methods, loads only what's needed
→ 75% token savings vs traditional approach
```

### Dependency Analysis ⭐ ENHANCED!
```
"What services does DefaultCheckoutFacade depend on?"
→ find_injected_dependencies shows ALL dependencies:
  • Field injection (@Autowired/@Resource/@Inject)
  • Constructor injection (with parameters)
  • Method injection (setter methods)
  • Spring XML property/constructor-arg refs
→ Complete dependency graph visibility
```

### Impact Analysis
```
"What depends on CheckoutService?"
→ Shows ALL classes using CheckoutService:
  • Via field injection
  • Via constructor injection
  • Via method injection
  • Via Spring XML configuration
→ Complete impact analysis for refactoring
```

### PR Review
```
"Review this PR for new PaymentValidationService"
→ Checks naming, patterns, missing updates
→ Comprehensive review in 2-3 minutes
```

## 🎯 Available Tools

1. **search_classes** - Find classes by name/pattern
2. **get_class_signature** - Get methods without loading file
3. **find_implementations** - Find all implementers
4. **find_usages** - Find where class is used
5. **find_injected_dependencies** - **⭐ ENHANCED!** Complete dependency analysis (field/constructor/method/XML)
6. **search_annotations** - Find annotated code
7. **get_spring_beans** - Search Spring beans
8. **rebuild_index** - Rebuild index
9. **get_index_stats** - Show statistics

## 📊 Performance

- **Indexing**: 300-500 classes/second
- **Search**: < 100ms typical
- **Index Size**: ~50MB for 10K classes
- **Memory**: ~100MB runtime

## 🗂️ Index Management

**Build once, use forever:**
- Core hybris code never changes → index stays fresh
- Rebuild weekly for team's new code
- Rebuild after hybris upgrade

```bash
# Check stats
Ask Claude: "Show index statistics"

# Rebuild if needed
Ask Claude: "Rebuild the index"

# Or clean start
rm ~/.sap-commerce-mcp/indexes/*.db
# Restart - auto rebuilds
```

## 🔍 Audit Logs

Every tool call logged:
```bash
tail -f ~/.sap-commerce-mcp/logs/audit-$(date +%Y-%m-%d).log
```

Example log:
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

## 🏗️ Architecture

```
┌─────────────────┐
│  Claude Code    │
└────────┬────────┘
         │ stdio (MCP SDK)
┌────────▼────────────────┐
│   MCP Server (Ruby SDK) │
│  ┌──────────────────┐   │
│  │  9 MCP Tools     │   │
│  └────────┬─────────┘   │
│  ┌────────▼─────────┐   │
│  │  SQLite Index    │   │
│  │  + Search Engine │   │
│  └──────────────────┘   │
└─────────────────────────┘
```

## 🛠️ Built With

- [MCP Ruby SDK](https://github.com/modelcontextprotocol/ruby-sdk) - Official protocol implementation
- SQLite3 - Fast indexing and queries
- Ruby 3.0+ - Modern Ruby features

## 📚 Documentation

- **[SETUP_GUIDE.md](SETUP_GUIDE.md)** - Complete setup instructions (Claude Code)
- **[INTELLIJ_COPILOT_SETUP.md](INTELLIJ_COPILOT_SETUP.md)** - ⭐ IntelliJ + GitHub Copilot setup
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Quick reference card
- **[COMMANDS.md](COMMANDS.md)** - Command cheatsheet
- **[CLAUDE.md](CLAUDE.md)** - Architecture and implementation details (for Claude Code)

## 🤝 Contributing

Issues and PRs welcome!

## 📄 License

MIT

## 🙏 Credits

- Built with [Official MCP Ruby SDK](https://github.com/modelcontextprotocol/ruby-sdk) by Anthropic/Shopify
- Designed for SAP Commerce Cloud development with Claude Code

---

**Ready to save tokens? See [SETUP_GUIDE.md](SETUP_GUIDE.md) to get started!**
