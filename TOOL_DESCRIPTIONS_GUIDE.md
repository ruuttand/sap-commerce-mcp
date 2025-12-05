# MCP Tool Description Best Practices

This guide explains how to write effective tool descriptions that help Claude choose the right tool at the right time.

## The Problem

Claude relies ENTIRELY on tool descriptions to decide when to use a tool. Poor descriptions lead to:
- Wrong tool selection ("I'll search the codebase with grep instead of your indexed search")
- Missed opportunities ("I didn't know you could do that")
- Parameter confusion ("What format should this query be?")

## Solution: Enhanced Tool Descriptions

### Formula for Effective Descriptions

```ruby
description <<~DESC
  [1-sentence primary purpose]

  Use this when:
  - [Specific user intent 1]
  - [Specific user intent 2]
  - [Specific user intent 3]

  Examples:
  - "[Example user question 1]" → query: "..."
  - "[Example user question 2]" → query: "...", filters: {...}

  Don't use this for:
  - [Anti-pattern 1] (use [alternative tool] instead)
  - [Anti-pattern 2]

  [Technical details/limitations]
DESC
```

## Real-World Examples

### BEFORE (Current)
```ruby
class SearchClasses < MCP::Tool
  title 'Search Classes'
  description 'Search for Java classes in the SAP Commerce project by name or pattern'
end
```

**Problems:**
- No guidance on when to use vs FindImplementations or FindUsages
- No examples of query syntax
- Claude doesn't know wildcards are supported
- No distinction from general code search

### AFTER (Improved)
```ruby
class SearchClasses < MCP::Tool
  title 'Search Classes'

  description <<~DESC
    Fast indexed search for Java classes in SAP Commerce by name or pattern.
    Returns class metadata (package, type, extension) without reading files.

    Use this when:
    - User asks "find class X" or "where is ProductService"
    - Need to locate classes by name pattern (e.g., "*Facade", "*Controller")
    - Want to filter by extension, type, or annotation
    - Exploring what classes exist in a package/extension

    Examples:
    - "Find ProductService" → query: "ProductService"
    - "Show me all facades" → query: "*Facade"
    - "List controllers in my extension" → query: "*Controller", filters: {extension: "myextension"}
    - "Find all @Service classes" → query: "*", filters: {annotation: "Service"}

    Don't use this for:
    - Finding implementations of an interface (use FindImplementations instead)
    - Finding which classes use/import a class (use FindUsages instead)
    - Reading class source code (use Read tool on the file_path from results)
    - Searching method bodies or field values

    Query supports wildcards: * (matches any chars), ? (matches one char)
    Results include: class name, package, file path, extension, type (class/interface/enum)
  DESC
end
```

### BEFORE (Current)
```ruby
class FindInjectedDependencies < MCP::Tool
  title 'Find Injected Dependencies'

  description <<~DESC
    Find Spring dependency injection relationships through field-level annotations.
    Useful for understanding which services are injected into a class, or finding all
    classes that depend on a specific service.

    Supports @Autowired, @Resource, and other Spring injection annotations.
  DESC
end
```

**Problems:**
- Doesn't explain the two distinct use cases clearly
- No examples showing the different query patterns
- Claude might not realize this is critical for dependency analysis
- No guidance on when to use class_name vs injected_type

### AFTER (Improved)
```ruby
class FindInjectedDependencies < MCP::Tool
  title 'Find Injected Dependencies'

  description <<~DESC
    Analyze Spring dependency injection at the field level using @Autowired, @Resource, @Inject annotations.
    Critical for understanding service dependencies in SAP Commerce where field injection is the primary DI pattern.

    Two main query modes:

    1. FORWARD LOOKUP: Find dependencies injected INTO a class
       - Use when: "What does class X depend on?", "Show dependencies of DefaultCheckoutFacade"
       - Parameter: class_name

    2. REVERSE LOOKUP: Find all classes that inject a specific type
       - Use when: "What depends on CheckoutService?", "Find all uses of CartService"
       - Parameter: injected_type

    Use this when:
    - Understanding service layer dependencies
    - Impact analysis: "If I change service X, what breaks?"
    - Architecture review: "How is this service used across the codebase?"
    - Debugging injection issues: "Which fields are being autowired?"

    Examples:
    - "What services does DefaultCheckoutFacade depend on?"
      → class_name: "DefaultCheckoutFacade"

    - "Find all classes that inject CheckoutService"
      → injected_type: "CheckoutService"

    - "Show only @Resource injections in DefaultCartService"
      → class_name: "DefaultCartService", annotation: "Resource"

    - "Which facades use ProductService?"
      → injected_type: "ProductService"

    Don't use this for:
    - Finding method calls (not field injection)
    - Finding Spring bean definitions in XML (use GetSpringBeans instead)
    - Finding classes that inherit/implement (use FindImplementations instead)

    Returns: field name, type, annotations, modifiers, containing class, extension
    Supports filtering by specific annotation type (Autowired, Resource, Inject, Qualifier)
  DESC
end
```

## Advanced Technique: MCP Prompts (Resources)

You can also add MCP **resources** (not just tools) that act as documentation Claude can read:

```ruby
# In your MCP server setup
server = MCP::Server.new(
  name: 'sap-commerce-mcp',
  version: '0.1.0',
  tools: tools,
  resources: [
    {
      uri: 'sap-commerce://guides/when-to-use-tools',
      name: 'Tool Selection Guide',
      description: 'Guide for choosing the right tool for different tasks',
      mimeType: 'text/markdown'
    }
  ],
  server_context: server_context
)
```

Claude can then read these resources when uncertain.

## Testing Your Descriptions

After updating descriptions, test with these questions:

**Ambiguous scenarios Claude should handle:**
1. "Find CheckoutService" → Should use SearchClasses, not Grep
2. "What depends on CheckoutService?" → Should use FindInjectedDependencies, not FindUsages
3. "Show me the ProductFacade class" → Should use GetClassSignature, not Read
4. "Find all classes using CartService" → Should use FindInjectedDependencies (injection), not FindUsages (imports)

**Edge cases:**
1. "Find all services" → SearchClasses with query="*Service"
2. "What classes does DefaultCheckoutFacade depend on?" → FindInjectedDependencies with class_name
3. "Show me facades that use CheckoutService" → FindInjectedDependencies with injected_type="CheckoutService" (then filter results)

## Implementation Priority

**High Impact** (Update these first):
1. `SearchClasses` - Most frequently used, needs disambiguation from grep/find
2. `FindInjectedDependencies` - New tool, needs clear guidance on two modes
3. `GetClassSignature` - Often confused with Read tool

**Medium Impact**:
4. `FindImplementations` - Clarify interface/class distinction
5. `FindUsages` - Explain import vs injection difference
6. `SearchAnnotations` - Add examples for common annotations

**Low Impact** (Already clear):
7. `GetSpringBeans` - Straightforward
8. `RebuildIndex` - Explicit user action
9. `GetIndexStats` - Simple statistics

## Measuring Success

After improving descriptions, monitor audit logs for:
- **Tool selection accuracy**: Are users getting results on first try?
- **Retry patterns**: Do users call multiple tools for same question?
- **Error rates**: Are invalid parameters being passed?

Check: `tail -f ~/.sap-commerce-mcp/logs/audit-$(date +%Y-%m-%d).log`
