# Setting Up SAP Commerce MCP Server with IntelliJ + GitHub Copilot

Complete step-by-step guide to integrate your SAP Commerce MCP server with IntelliJ IDEA and GitHub Copilot.

---

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Setup (5 minutes)](#quick-setup-5-minutes)
3. [Detailed Setup Steps](#detailed-setup-steps)
4. [Project-Level Setup (For Teams)](#project-level-setup-for-teams)
5. [Verification & Testing](#verification--testing)
6. [Usage Examples](#usage-examples)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software

- ✅ **IntelliJ IDEA** (2024.1 or later)
  - Community or Ultimate Edition
  - Any JetBrains IDE works (PyCharm, WebStorm, etc.)

- ✅ **GitHub Copilot Plugin** (v1.5.57 or higher)
  - Install from: Settings → Plugins → Marketplace → "GitHub Copilot"
  - Requires active GitHub Copilot subscription

- ✅ **Ruby 3.0+**
  ```bash
  ruby --version  # Should be 3.0 or higher
  ```

- ✅ **SAP Commerce MCP Server** (this project)
  - Already installed and working
  - Index built successfully

### Check Prerequisites

```bash
# 1. Verify Ruby version
ruby --version
# Expected: ruby 3.x.x

# 2. Verify MCP server works
cd /path/to/sap-commerce-mcp
bundle check
# Expected: The Gemfile's dependencies are satisfied

# 3. Test MCP server manually
bin/sap-commerce-mcp /path/to/hybris
# Expected: "Ready to receive MCP requests via stdio..."
# Press Ctrl+C to stop

# 4. Check IntelliJ Copilot plugin version
# Open IntelliJ → Settings → Plugins → Installed → GitHub Copilot
# Version should be ≥ 1.5.57
```

---

## Quick Setup (5 minutes)

### For Experienced Users

```bash
# 1. Create config directory
mkdir -p ~/.config/github-copilot/intellij

# 2. Create configuration file
cat > ~/.config/github-copilot/intellij/mcp.json <<'EOF'
{
  "mcpServers": {
    "sap-commerce": {
      "command": "/FULL/PATH/TO/sap-commerce-mcp/bin/sap-commerce-mcp",
      "args": ["/FULL/PATH/TO/your/hybris"]
    }
  }
}
EOF

# 3. Replace paths with YOUR actual paths
# Edit the file and update both paths
nano ~/.config/github-copilot/intellij/mcp.json

# 4. Make server executable (if not already)
chmod +x /FULL/PATH/TO/sap-commerce-mcp/bin/sap-commerce-mcp

# 5. Restart IntelliJ IDEA completely
# File → Exit (not just close window)

# 6. Test in IntelliJ
# Open Copilot Chat → Switch to Agent mode → Ask "Find ProductService"
```

**Done!** If it works, skip to [Usage Examples](#usage-examples).

---

## Detailed Setup Steps

### Step 1: Get Absolute Paths

**CRITICAL:** You MUST use absolute paths (no `~` or relative paths).

```bash
# 1a. Get absolute path to MCP server
cd /path/to/sap-commerce-mcp
pwd
# Copy this output (e.g., /Users/andree.ruut_1_2/git/sap-commerce-mcp)

# 1b. Get absolute path to hybris project
cd /path/to/your/hybris
pwd
# Copy this output (e.g., /Users/andree.ruut_1_2/git/kalmar-hybris)
```

**Write these down - you'll need them!**

### Step 2: Create Configuration Directory

**macOS/Linux:**
```bash
mkdir -p ~/.config/github-copilot/intellij
```

**Windows:**
```powershell
mkdir %APPDATA%\github-copilot\intellij
```

### Step 3: Create Configuration File

**macOS/Linux:**

```bash
# Open in your favorite editor
nano ~/.config/github-copilot/intellij/mcp.json
# Or use:
code ~/.config/github-copilot/intellij/mcp.json  # VS Code
open -a TextEdit ~/.config/github-copilot/intellij/mcp.json  # TextEdit
```

**Windows:**
```powershell
notepad %APPDATA%\github-copilot\intellij\mcp.json
```

**Paste this content:**
```json
{
  "mcpServers": {
    "sap-commerce": {
      "command": "/REPLACE/WITH/ABSOLUTE/PATH/TO/sap-commerce-mcp/bin/sap-commerce-mcp",
      "args": ["/REPLACE/WITH/ABSOLUTE/PATH/TO/your/hybris"]
    }
  }
}
```

### Step 4: Replace Paths with YOUR Paths

**Example (macOS/Linux):**
```json
{
  "mcpServers": {
    "sap-commerce": {
      "command": "/Users/andree.ruut_1_2/git/sap-commerce-mcp/bin/sap-commerce-mcp",
      "args": ["/Users/andree.ruut_1_2/git/kalmar-hybris"]
    }
  }
}
```

**Example (Windows):**
```json
{
  "mcpServers": {
    "sap-commerce": {
      "command": "C:\\Users\\YourName\\Projects\\sap-commerce-mcp\\bin\\sap-commerce-mcp",
      "args": ["C:\\Projects\\hybris"]
    }
  }
}
```

**Save the file!**

### Step 5: Validate JSON

```bash
# macOS/Linux
python3 -m json.tool ~/.config/github-copilot/intellij/mcp.json

# Windows
python -m json.tool %APPDATA%\github-copilot\intellij\mcp.json

# Expected: Clean JSON output (no errors)
```

If you get errors:
- ✅ Check for missing commas
- ✅ Check for missing quotes
- ✅ Check for correct brackets `{}`
- ✅ Windows: Use `\\` for paths, not `\`

### Step 6: Verify File Permissions

**macOS/Linux only:**
```bash
# Check if executable
ls -la /path/to/sap-commerce-mcp/bin/sap-commerce-mcp

# Should show: -rwxr-xr-x (executable flag set)
# If not, make it executable:
chmod +x /path/to/sap-commerce-mcp/bin/sap-commerce-mcp
```

### Step 7: Test MCP Server Manually

Before configuring IntelliJ, verify the server works:

```bash
# Run the server directly
/full/path/to/sap-commerce-mcp/bin/sap-commerce-mcp /full/path/to/hybris

# Expected output:
Starting SAP Commerce MCP Server...
Project: /full/path/to/hybris
Index found: ~/.sap-commerce-mcp/indexes/abc123.db
Registered 9 tools
Ready to receive MCP requests via stdio...

# Press Ctrl+C to stop
```

If this fails, **fix it first** before continuing!

### Step 8: Restart IntelliJ IDEA

**IMPORTANT:** Full restart required!

1. **File → Exit** (macOS: IntelliJ IDEA → Quit)
2. **Wait 5 seconds**
3. **Launch IntelliJ IDEA again**
4. **Open your SAP Commerce project**

### Step 9: Enable Copilot Agent Mode

1. Click **GitHub Copilot icon** (bottom right corner)
2. Select **Open Chat**
3. In chat window, look for **mode selector** (top of chat)
4. Switch from "Chat" to **"Agent"** mode

**Visual location:**
```
┌─────────────────────────────────┐
│ GitHub Copilot                  │
├─────────────────────────────────┤
│ [Chat ▼] [Agent ▼] ← Select    │
│                      Agent mode │
├─────────────────────────────────┤
│ Type your message...            │
└─────────────────────────────────┘
```

### Step 10: Verify MCP Tools Loaded

In Agent mode:

1. Click **🔧 tools icon** (bottom of chat window)
2. Should see section: **"MCP Tools"**
3. Should see: **"sap-commerce"** with 9 tools:
   - search_classes
   - get_class_signature
   - find_implementations
   - find_usages
   - find_injected_dependencies
   - search_annotations
   - get_spring_beans
   - rebuild_index
   - get_index_stats

**If you see this - SUCCESS! ✅**

---

## Project-Level Setup (For Teams)

Share MCP configuration with your team via project repository.

### Benefits
- ✅ One-time setup per project
- ✅ Team members get config automatically
- ✅ Version controlled configuration
- ✅ No manual path configuration needed

### Setup Steps

#### 1. Create Project Config File

```bash
# In your SAP Commerce project root (where pom.xml or build.gradle is)
cd /path/to/your/hybris-project

# Create .vscode directory
mkdir -p .vscode

# Create mcp.json
cat > .vscode/mcp.json <<'EOF'
{
  "mcpServers": {
    "sap-commerce": {
      "command": "${workspaceFolder}/../sap-commerce-mcp/bin/sap-commerce-mcp",
      "args": ["${workspaceFolder}"]
    }
  }
}
EOF
```

**Note:** `${workspaceFolder}` is replaced by IntelliJ/VS Code automatically with the project path.

#### 2. Adjust Paths for Your Setup

**If MCP server is in a different location:**
```json
{
  "mcpServers": {
    "sap-commerce": {
      "command": "/absolute/path/to/sap-commerce-mcp/bin/sap-commerce-mcp",
      "args": ["${workspaceFolder}"]
    }
  }
}
```

#### 3. Commit to Git

```bash
git add .vscode/mcp.json
git commit -m "Add SAP Commerce MCP server configuration for GitHub Copilot"
git push
```

#### 4. Team Members Setup

When team members clone/pull:

1. IntelliJ automatically detects `.vscode/mcp.json`
2. On first use, IntelliJ prompts: **"Start MCP servers?"**
3. Click **"Start"**
4. Tools become available immediately

**No manual configuration needed!** ✅

---

## Verification & Testing

### Test 1: Basic Search

**In IntelliJ Copilot Chat (Agent mode):**
```
Find ProductService in the codebase
```

**Expected behavior:**
1. Copilot shows: **"Using tool: search_classes"**
2. Returns: List of ProductService classes with locations
3. Response time: < 5 seconds

**Example response:**
```
I found 3 ProductService classes:

1. de.hybris.platform.product.ProductService (interface)
   Location: bin/platform/ext-commerce/...

2. de.hybris.platform.product.impl.DefaultProductService
   Location: bin/platform/ext-commerce/...

3. com.kalmar.core.service.CustomProductService
   Location: bin/custom/kalmarcore/...
```

### Test 2: Class Signature

```
What methods does DefaultCartService have?
```

**Expected:**
- Uses: `get_class_signature` tool
- Shows: Method signatures (NOT full implementation)
- Fast: < 3 seconds

### Test 3: Dependency Analysis ⭐

```
What services does DefaultCheckoutFacade depend on?
```

**Expected:**
- Uses: `find_injected_dependencies` tool
- Shows dependencies grouped by type:
  - Field Injection
  - Constructor Injection
  - Method Injection
  - Spring XML Injection

### Test 4: Implementation Search

```
Show me all implementations of ProductService
```

**Expected:**
- Uses: `find_implementations` tool
- Lists: All classes implementing ProductService interface

### Test 5: Impact Analysis

```
What classes inject CheckoutService?
```

**Expected:**
- Uses: `find_injected_dependencies` tool
- Shows: All classes using CheckoutService (any injection type)

---

## Usage Examples

### Example 1: Understanding Core Patterns

**Scenario:** You need to implement custom cart validation.

**In Copilot Chat:**
```
How does hybris implement cart validation?
```

**Copilot will:**
1. Use `search_classes` to find validation classes
2. Use `get_class_signature` to show structure
3. Use `find_implementations` to show examples
4. Provide architectural guidance

**You get:** Complete pattern in < 10 seconds!

### Example 2: Extending a Service

**Scenario:** Extend DefaultProductService with custom logic.

**In Copilot Chat:**
```
I want to extend DefaultProductService to add custom filtering.
Show me the structure and suggest implementation.
```

**Copilot will:**
1. Find DefaultProductService structure
2. Show relevant methods
3. Check dependencies
4. Generate extension code

### Example 3: PR Review

**Scenario:** Review teammate's PR adding PaymentValidationService.

**In Copilot Chat:**
```
Review this PaymentValidationService implementation:
[paste code]

Check:
- Does it follow hybris patterns?
- Are dependencies correct?
- Is Spring configuration needed?
```

**Copilot will:**
1. Search for similar validation services
2. Check naming conventions
3. Verify dependency patterns
4. Suggest Spring bean configuration

### Example 4: Refactoring Planning

**Scenario:** Planning to refactor CheckoutService.

**In Copilot Chat:**
```
What classes depend on CheckoutService?
I'm planning to refactor it.
```

**Copilot will:**
1. Use `find_injected_dependencies` (reverse lookup)
2. Show ALL classes using CheckoutService
3. List injection types (field/constructor/XML)
4. Help plan migration strategy

### Example 5: Creating New Features

**Scenario:** Create product recommendation service.

**In Copilot Chat:**
```
Create a custom ProductRecommendationService following hybris patterns.
Show me similar services first.
```

**Copilot will:**
1. Find similar services (*RecommendationService)
2. Show structure and dependencies
3. Generate skeleton code
4. Suggest Spring configuration

---

## Troubleshooting

### Problem 1: MCP Tools Not Showing

**Symptoms:**
- Copilot Chat works, but no MCP tools visible
- No "sap-commerce" in tools list

**Solutions:**

#### Check 1: Config file exists
```bash
# macOS/Linux
cat ~/.config/github-copilot/intellij/mcp.json

# Windows
type %APPDATA%\github-copilot\intellij\mcp.json

# Should show your configuration
```

#### Check 2: Validate JSON
```bash
python3 -m json.tool ~/.config/github-copilot/intellij/mcp.json
# Should output valid JSON without errors
```

#### Check 3: Verify paths are absolute
```json
{
  "mcpServers": {
    "sap-commerce": {
      "command": "/Users/...",  // ✅ Absolute
      "args": ["/Users/..."]    // ✅ Absolute
    }
  }
}

// ❌ WRONG:
"command": "~/git/..."      // Don't use ~
"command": "./bin/..."      // Don't use relative paths
```

#### Check 4: Test server manually
```bash
# Run the command from config file directly
/full/path/from/config/sap-commerce-mcp /full/path/to/hybris

# Should start without errors
```

#### Check 5: Check IntelliJ logs
```
Help → Show Log in Finder/Explorer
```

Search for:
- `MCP`
- `copilot`
- `sap-commerce`

Look for error messages.

#### Check 6: Restart IntelliJ properly
```
File → Exit (not just close window)
Wait 5 seconds
Launch IntelliJ again
```

### Problem 2: "Permission Denied" Error

**Error:**
```
Permission denied: /path/to/sap-commerce-mcp/bin/sap-commerce-mcp
```

**Solution:**
```bash
chmod +x /path/to/sap-commerce-mcp/bin/sap-commerce-mcp
```

### Problem 3: "Command Not Found"

**Error:**
```
/bin/sh: /path/to/sap-commerce-mcp: No such file or directory
```

**Solutions:**

1. **Verify path is correct:**
   ```bash
   ls -la /path/to/sap-commerce-mcp/bin/sap-commerce-mcp
   # Should show the file
   ```

2. **Use absolute path (no ~):**
   ```bash
   # Get absolute path
   cd /path/to/sap-commerce-mcp/bin
   pwd
   # Use this in config
   ```

### Problem 4: Server Starts But No Tools

**Symptoms:**
- "sap-commerce" shows in tools list
- But no individual tools listed (should be 9)

**Solutions:**

#### Check 1: Test tool discovery
```bash
# Run server and test manually
/path/to/sap-commerce-mcp/bin/sap-commerce-mcp /path/to/hybris

# In another terminal, test stdio
echo '{"jsonrpc":"2.0","method":"tools/list","id":1}' | \
  /path/to/sap-commerce-mcp/bin/sap-commerce-mcp /path/to/hybris
```

#### Check 2: Check index exists
```bash
ls -lh ~/.sap-commerce-mcp/indexes/
# Should show .db file

# If missing, rebuild:
rm -rf ~/.sap-commerce-mcp/indexes/
# Restart MCP server - will rebuild
```

#### Check 3: Update to latest version
```bash
cd /path/to/sap-commerce-mcp
git pull  # If using git
bundle install
```

### Problem 5: Agent Mode Not Available

**Symptoms:**
- Only "Chat" mode, no "Agent" option

**Solutions:**

1. **Update GitHub Copilot plugin:**
   ```
   Settings → Plugins → Installed → GitHub Copilot → Update
   ```

2. **Check plugin version:**
   - Must be ≥ v1.5.57
   - If older, update plugin

3. **Check enterprise policy:**
   - If in organization, admin must enable "MCP servers in Copilot"
   - Contact your GitHub admin

### Problem 6: Slow Responses

**Symptoms:**
- Tools work but take 30+ seconds
- IntelliJ freezes briefly

**Solutions:**

#### Check 1: Index size
```bash
du -h ~/.sap-commerce-mcp/indexes/
# Should be 50-100MB for typical project
# If > 200MB, might need optimization
```

#### Check 2: Optimize index
```bash
sqlite3 ~/.sap-commerce-mcp/indexes/*.db "VACUUM;"
```

#### Check 3: Rebuild index
```bash
rm ~/.sap-commerce-mcp/indexes/*.db
# Ask Copilot: "Rebuild the index"
```

### Problem 7: Works in Claude Code but Not IntelliJ

**This means:**
- ✅ MCP server is working correctly
- ❌ IntelliJ configuration issue

**Check:**
1. **Different config files:**
   - Claude Code: `~/.config/claude/mcp.json`
   - IntelliJ: `~/.config/github-copilot/intellij/mcp.json`

2. **Copy working config:**
   ```bash
   # Use same paths from Claude config
   cat ~/.config/claude/mcp.json
   # Copy to IntelliJ config
   ```

---

## Advanced Configuration

### Multiple MCP Servers

You can configure multiple MCP servers:

```json
{
  "mcpServers": {
    "sap-commerce": {
      "command": "/path/to/sap-commerce-mcp/bin/sap-commerce-mcp",
      "args": ["/path/to/hybris"]
    },
    "github": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"]
    },
    "postgres": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"]
    }
  }
}
```

All tools from all servers will be available in Copilot!

### Environment Variables

Pass environment variables to your MCP server:

```json
{
  "mcpServers": {
    "sap-commerce": {
      "command": "/path/to/sap-commerce-mcp/bin/sap-commerce-mcp",
      "args": ["/path/to/hybris"],
      "env": {
        "LOG_LEVEL": "debug",
        "CUSTOM_VAR": "value"
      }
    }
  }
}
```

### Per-Project Configuration

Different projects, different hybris paths:

**Project A:** `.vscode/mcp.json`
```json
{
  "mcpServers": {
    "sap-commerce": {
      "command": "/path/to/sap-commerce-mcp/bin/sap-commerce-mcp",
      "args": ["${workspaceFolder}/hybris-project-a"]
    }
  }
}
```

**Project B:** `.vscode/mcp.json`
```json
{
  "mcpServers": {
    "sap-commerce": {
      "command": "/path/to/sap-commerce-mcp/bin/sap-commerce-mcp",
      "args": ["${workspaceFolder}/hybris-project-b"]
    }
  }
}
```

IntelliJ loads the correct config for each project automatically!

---

## Quick Reference

### File Locations

```bash
# IntelliJ global config
~/.config/github-copilot/intellij/mcp.json  # macOS/Linux
%APPDATA%\github-copilot\intellij\mcp.json  # Windows

# Project-level config
.vscode/mcp.json  # In project root

# MCP server index
~/.sap-commerce-mcp/indexes/*.db

# MCP server logs
~/.sap-commerce-mcp/logs/audit-*.log
```

### Useful Commands

```bash
# Validate config
python3 -m json.tool ~/.config/github-copilot/intellij/mcp.json

# Test server
/path/to/bin/sap-commerce-mcp /path/to/hybris

# Check index
ls -lh ~/.sap-commerce-mcp/indexes/

# View logs
tail -f ~/.sap-commerce-mcp/logs/audit-$(date +%Y-%m-%d).log

# Rebuild index
rm ~/.sap-commerce-mcp/indexes/*.db
```

### Keyboard Shortcuts

```
# Open Copilot Chat
Cmd+Shift+A → "Copilot Chat"  # macOS
Ctrl+Shift+A → "Copilot Chat"  # Windows/Linux

# Or click GitHub Copilot icon (bottom right)
```

---

## Success Checklist

After setup, you should have:

- ✅ Config file created at correct location
- ✅ Paths are absolute (no ~ or relative)
- ✅ JSON is valid (verified with json.tool)
- ✅ MCP server executable (chmod +x)
- ✅ IntelliJ restarted completely
- ✅ Agent mode available in Copilot Chat
- ✅ "sap-commerce" shows in tools list
- ✅ 9 tools visible under sap-commerce
- ✅ Test query works (Find ProductService)
- ✅ Tools execute in < 5 seconds
- ✅ Audit logs show tool usage

---

## Next Steps

### 1. Learn MCP Tool Capabilities

See [QUICK_REFERENCE.md](QUICK_REFERENCE.md) for all 9 tools and usage examples.

### 2. Daily Workflow

Keep IntelliJ open with Copilot Chat visible:
- Left: Code editor
- Right: Copilot Chat (Agent mode)

Ask questions as you code!

### 3. Team Onboarding

Share `.vscode/mcp.json` with team:
```bash
git add .vscode/mcp.json
git commit -m "Add SAP Commerce MCP config"
git push
```

### 4. Monitor Performance

Check audit logs periodically:
```bash
tail -50 ~/.sap-commerce-mcp/logs/audit-*.log
```

### 5. Index Maintenance

Rebuild weekly or after hybris upgrades:
```bash
# Ask Copilot:
"Rebuild the SAP Commerce index"
```

---

## Resources

### Documentation
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Tool usage guide
- [COMMANDS.md](COMMANDS.md) - Command cheatsheet
- [SETUP_GUIDE.md](SETUP_GUIDE.md) - Complete server setup
- [ENHANCEMENT_SUMMARY.md](ENHANCEMENT_SUMMARY.md) - Latest enhancements

### External Links
- [GitHub Copilot MCP Documentation](https://docs.github.com/copilot/customizing-copilot/using-model-context-protocol/extending-copilot-chat-with-mcp)
- [IntelliJ MCP Documentation](https://www.jetbrains.com/help/idea/mcp-server.html)
- [Model Context Protocol](https://modelcontextprotocol.io)

---

## Support

### Getting Help

1. **Check troubleshooting section** above
2. **Review IntelliJ logs:** Help → Show Log in Finder/Explorer
3. **Test server manually** to isolate issue
4. **Check audit logs** for MCP server errors

### Common Issues

| Problem | Quick Fix |
|---------|-----------|
| Tools not showing | Restart IntelliJ completely |
| Permission denied | `chmod +x bin/sap-commerce-mcp` |
| Invalid JSON | Use `json.tool` to validate |
| Server not found | Use absolute paths (no ~) |
| Slow responses | Rebuild index |

---

**Ready to supercharge your SAP Commerce development with IntelliJ + Copilot + MCP! 🚀**

Questions? Check the troubleshooting section or review the audit logs for detailed error messages.
