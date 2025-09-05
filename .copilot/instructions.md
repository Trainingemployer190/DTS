# Copilot Instructions for DTS App

## GraphQL Development Guidelines

When working with GraphQL code in this project:

### Required References
- **Schema**: `DTS App/DTS App/Docs/GraphQL/jobber_schema.graphql.txt` (60,218+ lines)
- **API Guide**: `DTS App/DTS App/Docs/GraphQL/JOBBER_API_REFERENCE.md`
- **Existing Code**: `DTS App/DTS App/Managers/JobberAPI.swift`

### Key Rules
1. **Always validate field names against the schema file first**
2. **Use Base64 ID extraction for web URLs** (see `DataModels.swift` `extractNumericId`)
3. **Follow existing query patterns** from `JobberAPI.swift`
4. **Include debug logging** for ID transformations
5. **Handle GraphQL errors** properly

### ID Conversion Pattern
```swift
// GraphQL returns: "Z2lkOi8vSm9iYmVyL0NsaWVudC84MDA0NDUzOA=="
// Decodes to: "gid://Jobber/Client/80044538"
// Web URL needs: "80044538"
```

### Verification Steps
- [ ] Check schema for field existence
- [ ] Validate field types and relationships  
- [ ] Ensure proper ID handling
- [ ] Test with existing patterns
- [ ] Add appropriate logging

*Reference the full GraphQL schema documentation before implementing any GraphQL-related functionality.*
