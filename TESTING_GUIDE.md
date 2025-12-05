# Testing Guide: Enhanced Dependency Tracking

## Prerequisites

The enhanced dependency tracking requires a **fresh index** because the database schema has changed.

## Step 1: Clean Old Index

```bash
# Remove old index database
rm ~/.sap-commerce-mcp/indexes/*.db

# Or, if you want to keep a backup:
mv ~/.sap-commerce-mcp/indexes/*.db ~/backup-index.db
```

## Step 2: Syntax Verification (Already Done ✅)

All modified files passed syntax checks:
- `lib/sap_commerce_mcp/parser/sap_commerce_parser.rb` ✅
- `lib/sap_commerce_mcp/parser/java_parser.rb` ✅
- `lib/sap_commerce_mcp/indexer.rb` ✅
- `lib/sap_commerce_mcp/tools/find_injected_dependencies.rb` ✅

## Step 3: Test with Sample SAP Commerce Project

### Option A: Use bin/sap-commerce-mcp directly

```bash
# Run the MCP server with your project path
bin/sap-commerce-mcp /path/to/your/hybris/project
```

This will:
1. Discover extensions
2. Parse Java files (now including constructor params)
3. Parse Spring XML files (now including dependencies)
4. Build the index with new schema
5. Start the MCP server

### Option B: Use via Claude Code

If configured with Claude Code:
```bash
# The server will auto-start when Claude Code launches
# Use the find_injected_dependencies tool via Claude
```

## Step 4: Verify New Functionality

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

## Step 5: Verify Index Statistics

Use the `get_index_stats` MCP tool to verify new tables exist:

**Expected to see:**
- `classes` count
- `methods` count
- `fields` count
- `constructor_params` count ← **NEW**
- `bean_dependencies` count ← **NEW**
- `annotations` count (should be higher with constructor annotations)
- `spring_beans` count

## Step 6: Performance Check

Compare indexing time:
- **Before**: ~300-500 classes/second
- **After**: ~270-450 classes/second (5-10% slower is expected)

Index size:
- **Before**: ~50MB for 10K classes
- **After**: ~55-60MB for 10K classes (10-15% larger is expected)

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

## Success Indicators

✅ All syntax checks pass
✅ Index builds without errors
✅ New tables (constructor_params, bean_dependencies) are populated
✅ Queries return results from all injection types
✅ Performance degradation < 10%

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

## Next Steps After Successful Testing

1. Commit the changes
2. Update version number
3. Document in release notes
4. Consider adding integration tests
5. Monitor performance in production
