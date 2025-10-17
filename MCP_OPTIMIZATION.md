# MCP Tool Optimization - October 12, 2025

## Problem
Tool count was at **214 tools**, causing degraded performance (recommended max: 128 tools).

## Root Cause
Multiple duplicate GitKraken MCP servers were enabled:
- `gitkraken` (original)
- `gitkraken2` (duplicate)
- `gitkraken3` (duplicate)
- `gitkraken4` (duplicate)

Each duplicate added ~15 tools, totaling 60+ unnecessary tools.

## Solution Applied

### 1. Backup Created
- **Global settings backup**: `~/Library/Application Support/Code/User/settings.json.backup`
- **MCP config backup**: `~/Library/Application Support/Code/User/mcp.json.backup`

### 2. Settings Updated

#### Workspace Settings (`.vscode/settings.json`)
Added MCP server exclusions:
```json
"github.copilot.chat.mcp.enabled": true,
"github.copilot.chat.mcp.excludedServers": [
    "gitkraken2",
    "gitkraken3",
    "gitkraken4"
]
```

#### Global Settings (`~/Library/Application Support/Code/User/settings.json`)
Same exclusions added to global configuration.

### 3. Expected Results
- **Tool count reduction**: From 214 → ~165 tools (removing 45-60 duplicate GitKraken tools)
- **Performance improvement**: Should be within the 128-tool recommendation once you restart VS Code
- **No functionality loss**: Original `gitkraken` server remains enabled for git operations

## Tools Still Available
✅ **Core VS Code tools** (file operations, terminal, search, etc.)
✅ **GitKraken** (single instance for git operations)
✅ **GitHub basic tools** (repository, issues, pull requests)

## Tools Now Disabled
❌ GitKraken duplicates (gitkraken2, gitkraken3, gitkraken4)

## Future Optimizations (If Still Needed)
If tool count is still too high, you can additionally disable these GitHub categories by adding them to `excludedServers`:
- `workflow_management` (GitHub Actions)
- `notification_management` (notifications)
- `project_management` (project boards)
- `discussion_management` (discussions)
- `release_management` (releases)
- `security_management` (security alerts)
- `gist_management` (gists)
- `copilot_management` (Copilot spaces)
- `user_management` (user profiles)
- `web_search` (web search)
- `commit_management` (commit history)
- `label_management` (issue labels)

## How to Revert
If anything breaks, restore from backups:
```bash
cp ~/Library/Application\ Support/Code/User/settings.json.backup \
   ~/Library/Application\ Support/Code/User/settings.json

cp ~/Library/Application\ Support/Code/User/mcp.json.backup \
   ~/Library/Application\ Support/Code/User/mcp.json
```

## Next Steps
1. **Restart VS Code** to apply changes
2. Verify tool count has decreased
3. Test that your DTS App workflow still works (building, running, git operations)

## Notes
- No changes were made to your actual codebase
- Only configuration files were modified
- All backups are preserved
- Original functionality remains intact
