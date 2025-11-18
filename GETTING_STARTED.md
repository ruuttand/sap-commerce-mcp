# Getting Started Checklist

Complete this checklist to get your SAP Commerce MCP Server running with Claude Code.

## ✅ Prerequisites

- [ ] Ruby 3.0 or higher installed
  ```bash
  ruby --version
  ```
  
- [ ] Access to SAP Commerce Cloud project (hybris directory)
  ```bash
  ls /path/to/hybris/bin/custom
  ```

- [ ] Claude Code installed and working

---

## ✅ Phase 1: Installation (5 min)

- [ ] **Navigate to project directory**
  ```bash
  cd sap-commerce-mcp-sdk
  ```

- [ ] **Install dependencies**
  ```bash
  bundle install
  gem install mcp
  ```
  ✓ Expected: "Bundle complete! X Gemfile dependencies"

- [ ] **Make executable**
  ```bash
  chmod +x bin/sap-commerce-mcp
  ```

- [ ] **Verify installation**
  ```bash
  ruby -c bin/sap-commerce-mcp
  ```
  ✓ Expected: "Syntax OK"

---

## ✅ Phase 2: Build Index (10-15 min)

- [ ] **Start server (will auto-build index)**
  ```bash
  bin/sap-commerce-mcp /path/to/your/hybris
  ```
  
  ✓ Expected output:
  ```
  Starting SAP Commerce MCP Server...
  Project: /path/to/hybris
  No index found. Building initial index...
  Index built: XXXX classes, XXXXX methods
  Registered 8 tools
  Ready to receive MCP requests via stdio...
  ```

- [ ] **Verify index created**
  ```bash
  ls -lh ~/.sap-commerce-mcp/indexes/
  ```
  ✓ Expected: See .db file (20-100 MB)

- [ ] **Check index contents**
  ```bash
  sqlite3 ~/.sap-commerce-mcp/indexes/*.db "SELECT COUNT(*) FROM classes;"
  ```
  ✓ Expected: Number matching your project size

**Note:** Server will keep running. Open a new terminal for next steps.

---

## ✅ Phase 3: Configure Claude Code (5 min)

- [ ] **Add your MCP server**
  ```bash
  claude mcp add sap-commerce --scope user -- /FULL/PATH/TO/sap-commerce-mcp/bin/sap-commerce-mcp /FULL/PATH/TO/your/hybris
  ```

- [ ] **Restart Claude Code**
  - Quit Claude Code completely
  - Start Claude Code again
  ✓ MCP servers load on startup

---

## ✅ Phase 4: Test It Works (5 min)

### Test 1: Simple Search

- [ ] **In Claude Code, type:**
  ```
  Find ProductService in my hybris project
  ```

- [ ] **Verify Claude uses MCP tool**
  ✓ You should see: "Using tool: search_classes" or similar
  
- [ ] **Check response is fast**
  ✓ Results in < 5 seconds
  
- [ ] **Verify results shown**
  ✓ Shows: DefaultProductService, ProductService interface, etc.

### Test 2: Check Audit Log

- [ ] **Open audit log**
  ```bash
  tail -20 ~/.sap-commerce-mcp/logs/audit-$(date +%Y-%m-%d).log
  ```

- [ ] **Verify log entry exists**
  ✓ Should show JSON with:
  ```json
  {
    "tool": "search_classes",
    "input": {"query": "ProductService"},
    "output": {"result_count": X}
  }
  ```

### Test 3: Method Signatures

- [ ] **Ask Claude:**
  ```
  What methods does DefaultCartService have?
  ```

- [ ] **Verify uses correct tool**
  ✓ Should use: get_class_signature

- [ ] **Verify shows method signatures**
  ✓ Lists: addToCart(), removeFromCart(), etc.
  ✓ Does NOT show full implementation

### Test 4: Find Implementations

- [ ] **Ask Claude:**
  ```
  Show me all implementations of ProductService
  ```

- [ ] **Verify tool usage**
  ✓ Uses: find_implementations

- [ ] **Verify results**
  ✓ Shows: DefaultProductService, CustomProductService, etc.

---

## ✅ Phase 5: Advanced Tests (Optional)

### Test 5: Annotations

- [ ] **Ask Claude:**
  ```
  Find all @Controller classes in commercewebservices
  ```

- [ ] **Verify results**
  ✓ Uses: search_annotations
  ✓ Shows controller classes

### Test 6: Spring Beans

- [ ] **Ask Claude:**
  ```
  Find Spring beans related to cart
  ```

- [ ] **Verify results**
  ✓ Uses: get_spring_beans
  ✓ Shows bean definitions

### Test 7: Statistics

- [ ] **Ask Claude:**
  ```
  Show me the index statistics
  ```

- [ ] **Verify output**
  ✓ Shows: classes_count, methods_count, etc.

---

## ✅ Troubleshooting Checklist

If tests fail, check:

### Server Issues

- [ ] Server running in terminal?
  ✓ Should show: "Ready to receive MCP requests"

- [ ] No error messages in server output?

- [ ] Index file exists?
  ```bash
  ls ~/.sap-commerce-mcp/indexes/
  ```

### Configuration Issues

- [ ] mcp.json has absolute paths?
  ```bash
  cat ~/.config/claude/mcp.json
  ```
  ✓ Paths start with `/` or `C:\`

- [ ] mcp.json is valid JSON?
  ```bash
  python3 -m json.tool ~/.config/claude/mcp.json
  ```

- [ ] Claude Code restarted after config change?

### Claude Not Using Tools

- [ ] Check Claude sees the tools
  - Ask: "What MCP tools do you have access to?"
  - Should mention: search_classes, get_class_signature, etc.

- [ ] Check logs for errors
  ```bash
  tail -50 ~/.sap-commerce-mcp/logs/audit-*.log
  ```

---

## ✅ Final Verification

- [ ] All 4 basic tests passed
- [ ] Audit logs show tool usage
- [ ] Responses are fast (< 5 seconds)
- [ ] No error messages in logs
- [ ] Claude mentions using MCP tools

---

## 🎉 Success Criteria

You're ready when:

✅ Claude uses MCP tools automatically  
✅ Search results appear in < 5 seconds  
✅ Audit logs show successful tool calls  
✅ No error messages in server or logs  
✅ Can find classes, methods, implementations  

---

## 📚 Next Steps

Now that it's working:

1. **Read:** [QUICK_REFERENCE.md](QUICK_REFERENCE.md) for common commands
2. **Try:** Complex queries (PR review, extending services)
3. **Monitor:** Audit logs to see token savings
4. **Maintain:** Rebuild index weekly or after hybris upgrade

---

## 🆘 Still Having Issues?

**Common problems:**

1. **"Tool not found"**
   - Check mcp.json paths are absolute
   - Restart Claude Code

2. **"No results"**
   - Check index was built
   - Verify project path correct
   - Try rebuilding index

3. **"Slow responses"**
   - Check server is running
   - Verify index file not corrupted
   - Check disk space

4. **"Permission denied"**
   - Run: `chmod +x bin/sap-commerce-mcp`
   - Check file ownership

**Need more help?**
- Review [SETUP_GUIDE.md](SETUP_GUIDE.md)
- Check audit logs for errors
- Verify all paths in configuration

---

**Checklist complete? You're ready to boost your SAP Commerce development! 🚀**
