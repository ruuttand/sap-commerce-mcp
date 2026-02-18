# Testing Guide

## Overview

This guide covers testing for two major enhancements:
1. **Enhanced Dependency Tracking** - Constructor/Method/XML injection
2. **Tree-Sitter Parser (Phase 1)** - Generic types, inner classes, complex annotations

## Prerequisites

Both enhancements require a **fresh index** because the database schema has changed.

### Optional: Tree-Sitter Grammar

If you want to test tree-sitter mode:
```bash
# Install grammar (see SETUP_GUIDE.md for full instructions)
mkdir -p ~/.sap-commerce-mcp/grammars
# Copy compiled libtree-sitter-java.dylib to grammars directory
```

## Step 1: Clean Old Index

```bash
# Remove old index database
rm ~/.sap-commerce-mcp/indexes/*.db

# Or, if you want to keep a backup:
mv ~/.sap-commerce-mcp/indexes/*.db ~/backup-index.db
```

## Step 2: Syntax Verification

Run syntax checks on all modified files:

```bash
# Core files
ruby -c lib/sap_commerce_mcp/parser/sap_commerce_parser.rb
ruby -c lib/sap_commerce_mcp/parser/java_parser.rb
ruby -c lib/sap_commerce_mcp/indexer.rb
ruby -c lib/sap_commerce_mcp/tools/find_injected_dependencies.rb

# Tree-sitter files
ruby -c lib/sap_commerce_mcp/parser/tree_sitter_java_parser.rb
ruby -c lib/sap_commerce_mcp/parser/tree_sitter/grammar_loader.rb

# Main executable
ruby -c bin/sap-commerce-mcp
```

All should return `Syntax OK`.

## Step 3: Test with Sample SAP Commerce Project

### Option A: Use bin/sap-commerce-mcp directly

**Standard mode (regex parser):**
```bash
bin/sap-commerce-mcp /path/to/your/hybris/project
```

**Enhanced mode (tree-sitter parser):**
```bash
SAP_MCP_USE_TREE_SITTER=true bin/sap-commerce-mcp /path/to/your/hybris/project
```

This will:
1. Discover extensions
2. Parse Java files (with tree-sitter if enabled)
3. Extract classes, methods, fields, annotations, constructor params
4. Parse Spring XML files (dependencies)
5. Build the index with enhanced schema
6. Start the MCP server

### Option B: Use via Claude Code

Configure in `~/.config/claude/mcp.json`:

**Standard mode:**
```json
{
  "mcpServers": {
    "sap-commerce": {
      "command": "/path/to/bin/sap-commerce-mcp",
      "args": ["/path/to/hybris"]
    }
  }
}
```

**Enhanced mode (tree-sitter):**
```json
{
  "mcpServers": {
    "sap-commerce": {
      "command": "/path/to/bin/sap-commerce-mcp",
      "args": ["/path/to/hybris"],
      "env": {
        "SAP_MCP_USE_TREE_SITTER": "true"
      }
    }
  }
}
```

Restart Claude Code - the server will auto-start when needed.

## Step 4: Run Unit Tests

Run the test suite to verify all functionality:

```bash
# Run all tests
bundle exec rake test

# Run specific test files
bundle exec ruby test/unit/tree_sitter_java_parser_test.rb
bundle exec ruby test/unit/tree_sitter_java_parser_phase1_test.rb

# Expected output
20 tests, 78 assertions, 0 failures, 0 errors
```

## Step 5: Verify Enhanced Dependency Tracking

### Test Case 1: Constructor Injection

Find a class that uses constructor injection:

```java
@Service
public class MyFacade {
    @Autowired
    public MyFacade(ProductService productService, CartService cartService) {
        // ...
    }
}
```

**Query**: "What services does MyFacade depend on?"

**Expected Result**: Should show:
- Constructor Injection section with `productService` and `cartService`

### Test Case 2: Spring XML Dependencies

Find a bean with XML configuration:

```xml
<bean id="checkoutFacade" class="com.example.DefaultCheckoutFacade">
    <property name="checkoutService" ref="checkoutService"/>
    <property name="cartService" ref="cartService"/>
</bean>
```

**Query**: "What does DefaultCheckoutFacade depend on?"

**Expected Result**: Should show:
- Spring XML Injection section with `checkoutService` and `cartService` properties

### Test Case 3: Method Injection

Find a class with setter injection:

```java
@Service
public class MyService {
    @Autowired
    public void setProductService(ProductService productService) {
        // ...
    }
}
```

**Query**: "What depends on ProductService?"

**Expected Result**: Should include:
- Method Injection section showing `setProductService` in MyService

### Test Case 4: All Injection Types Combined

**Query**: "What classes inject CheckoutService?"

**Expected Result**: Should show classes grouped by injection type:
- Field Injection (classes with @Autowired private CheckoutService)
- Constructor Injection (classes with @Autowired constructor param)
- Method Injection (classes with @Autowired setter)
- Spring XML Injection (beans with property/constructor-arg refs)

## Step 6: Verify Tree-Sitter Parser (If Enabled)

### Test Case 1: Generic Type Extraction

Find a class with generic fields:

```java
public class ProductCache {
    private Map<String, List<ProductModel>> productsByCategory;
    private List<String> categoryIds;
}
```

**Test**:
```bash
sqlite3 ~/.sap-commerce-mcp/indexes/*.db \
  "SELECT name, generic_type FROM fields WHERE name = 'productsByCategory';"
```

**Expected Result**:
```
productsByCategory|Map<String, List<ProductModel>>
```

**Without tree-sitter**: `generic_type` would be NULL or partial.

### Test Case 2: Inner Class Detection

Find a class with inner classes:

```java
public class OuterClass {
    static class StaticInner { }
    class InnerClass {
        class DeeplyNested { }
    }
}
```

**Test**:
```bash
sqlite3 ~/.sap-commerce-mcp/indexes/*.db \
  "SELECT name, is_inner_class, parent_class_id FROM classes WHERE name LIKE '%Inner%';"
```

**Expected Result**: Should show:
- `StaticInner` with `is_inner_class=1` and `parent_class_id` pointing to OuterClass
- `InnerClass` with `is_inner_class=1`
- `DeeplyNested` with `is_inner_class=1` and `parent_class_id` pointing to InnerClass

**Without tree-sitter**: Inner classes not detected at all.

### Test Case 3: Complex Annotations

Find a controller with multi-line annotations:

```java
@RequestMapping(
    value = "/api/products",
    method = RequestMethod.GET,
    produces = "application/json"
)
public class ProductController {
}
```

**Test**:
```bash
sqlite3 ~/.sap-commerce-mcp/indexes/*.db \
  "SELECT annotation_name, parameters FROM annotations WHERE annotation_name = 'RequestMapping' LIMIT 1;"
```

**Expected Result**:
```
RequestMapping|{"value":"\"/api/products\"","method":"RequestMethod.GET","produces":"\"application/json\""}
```

**Without tree-sitter**: Annotation might be missed or have NULL parameters.

### Test Case 4: Generic Method Signatures

Find a generic method:

```java
public <T extends Model> T findById(String id) {
    // ...
}
```

**Test**:
```bash
sqlite3 ~/.sap-commerce-mcp/indexes/*.db \
  "SELECT name, generic_signature, return_type FROM methods WHERE name = 'findById';"
```

**Expected Result**:
```
findById|<T extends Model>|T
```

**Without tree-sitter**: `generic_signature` would be NULL.

## Step 7: Verify Index Statistics

Use the `get_index_stats` MCP tool to verify new tables exist:

**Expected to see:**
- `classes_count`
- `methods_count`
- `fields_count`
- `constructor_params` count ← **NEW (Dependency Tracking)**
- `bean_dependencies` count ← **NEW (Dependency Tracking)**
- `annotations_count` (higher with tree-sitter + dependency tracking)
- `spring_beans_count`
- `extensions_count`

**Direct database check:**
```bash
sqlite3 ~/.sap-commerce-mcp/indexes/*.db << EOF
SELECT 'Classes', COUNT(*) FROM classes
UNION SELECT 'Methods', COUNT(*) FROM methods
UNION SELECT 'Fields', COUNT(*) FROM fields
UNION SELECT 'Constructor Params', COUNT(*) FROM constructor_params
UNION SELECT 'Bean Dependencies', COUNT(*) FROM bean_dependencies
UNION SELECT 'Annotations', COUNT(*) FROM annotations;
EOF
```

## Step 8: Performance Check

### Indexing Speed

| Parser Mode | Speed | Notes |
|-------------|-------|-------|
| Regex (baseline) | ~300-500 classes/sec | Original performance |
| Regex + dependency tracking | ~270-450 classes/sec | 5-10% slower (expected) |
| Tree-sitter | ~300-500 classes/sec | Similar to regex |
| Tree-sitter + dependency | ~250-450 classes/sec | Slightly slower (acceptable) |

### Index Size

| Configuration | Size (10K classes) | Increase |
|---------------|-------------------|----------|
| Regex baseline | ~50MB | - |
| + Dependency tracking | ~55-60MB | +10-15% |
| + Tree-sitter (no deps) | ~52-55MB | +5-10% |
| Full (tree-sitter + deps) | ~60-65MB | +20-25% |

**Size increase is expected** due to:
- Constructor params table
- Bean dependencies table
- Generic type signatures
- Annotation parameters (JSON)
- Inner class relationships

## Common Issues & Solutions

### Issue: "Table not found" errors

**Cause**: Old index still being used

**Solution**:
```bash
rm ~/.sap-commerce-mcp/indexes/*.db
# Restart MCP server
```

### Issue: No constructor injections found

**Possible causes:**
1. Class doesn't have `@Autowired` on constructor
2. Constructor params don't have types indexed

**Debug**: Check if constructor_params table has data:
```bash
sqlite3 ~/.sap-commerce-mcp/indexes/*.db "SELECT COUNT(*) FROM constructor_params;"
```

### Issue: No XML dependencies found

**Possible causes:**
1. Spring XML files don't use `<property ref="...">` (might use `<property value="...">`)
2. Beans don't have IDs

**Debug**: Check if bean_dependencies table has data:
```bash
sqlite3 ~/.sap-commerce-mcp/indexes/*.db "SELECT COUNT(*) FROM bean_dependencies;"
```

### Issue: Tree-sitter grammar not found

**Error**: `Tree-sitter Java grammar not found at ~/.sap-commerce-mcp/grammars/...`

**Solution**:
```bash
# Option 1: Install grammar (see SETUP_GUIDE.md)
# Option 2: Disable tree-sitter
# Remove SAP_MCP_USE_TREE_SITTER from environment/config
```

### Issue: Generic types showing as NULL

**Cause**: Using regex parser instead of tree-sitter

**Solution**:
```bash
# Enable tree-sitter mode
SAP_MCP_USE_TREE_SITTER=true bin/sap-commerce-mcp /path/to/hybris

# Or set in MCP config:
# "env": { "SAP_MCP_USE_TREE_SITTER": "true" }
```

### Issue: Inner classes not found

**Cause**: Regex parser doesn't detect inner classes

**Solution**: Must use tree-sitter parser (see above)

### Issue: Annotation parameters showing as NULL

**Cause**: Using regex parser for complex annotations

**Solution**: Enable tree-sitter parser for full annotation parameter extraction

## Success Indicators

### Core Functionality
✅ All syntax checks pass
✅ Index builds without errors (both regex and tree-sitter modes)
✅ All 20 unit tests pass (78 assertions)

### Enhanced Dependency Tracking
✅ New tables (constructor_params, bean_dependencies) are populated
✅ Queries return results from all injection types (field/constructor/method/XML)
✅ Performance degradation < 10%

### Tree-Sitter Parser (If Enabled)
✅ Generic types fully extracted (not NULL)
✅ Inner classes detected with proper parent relationships
✅ Annotation parameters stored as JSON
✅ Generic method signatures captured
✅ Index size increase 20-25% (expected)
✅ Indexing speed similar to regex parser

### Overall
✅ MCP tools work with both parsers
✅ Backward compatibility maintained (regex is default)
✅ Feature flag works (`SAP_MCP_USE_TREE_SITTER=true`)
✅ No crashes or errors during indexing

## Rollback Plan (If Needed)

If issues occur, you can rollback by:

1. Restore old code:
```bash
git checkout HEAD~1 lib/sap_commerce_mcp/
```

2. Restore old index (if backed up):
```bash
mv ~/backup-index.db ~/.sap-commerce-mcp/indexes/<hash>.db
```

3. Restart MCP server

## Comparison Testing

To verify tree-sitter provides better results, compare the same codebase with both parsers:

```bash
# 1. Index with regex parser
rm ~/.sap-commerce-mcp/indexes/*.db
bin/sap-commerce-mcp /path/to/hybris
# Note the index location

# 2. Rename the index
mv ~/.sap-commerce-mcp/indexes/*.db ~/.sap-commerce-mcp/indexes/regex-index.db

# 3. Index with tree-sitter parser
SAP_MCP_USE_TREE_SITTER=true bin/sap-commerce-mcp /path/to/hybris
# New index created

# 4. Rename the tree-sitter index
mv ~/.sap-commerce-mcp/indexes/*.db ~/.sap-commerce-mcp/indexes/treesitter-index.db

# 5. Compare results
# Regex parser
sqlite3 ~/.sap-commerce-mcp/indexes/regex-index.db \
  "SELECT COUNT(*) FROM fields WHERE generic_type IS NOT NULL;"

# Tree-sitter parser
sqlite3 ~/.sap-commerce-mcp/indexes/treesitter-index.db \
  "SELECT COUNT(*) FROM fields WHERE generic_type IS NOT NULL;"

# Tree-sitter should show MUCH higher count
```

**Expected differences:**
- Tree-sitter has 50-100x more generic_type entries
- Tree-sitter has inner classes (regex has 0)
- Tree-sitter has more annotations with parameters
- Both have same core class/method/field counts

## Next Steps After Successful Testing

1. ✅ Commit the changes
2. ✅ Update version number
3. ✅ Document in release notes
4. ✅ Update all documentation (README, CLAUDE.md, SETUP_GUIDE, etc.)
5. Consider adding more integration tests
6. Monitor performance in production
7. Gather user feedback on tree-sitter vs regex parser
