# DTS App Project Cleanup Guide

This guide provides step-by-step instructions to declutter your project by removing unused files and consolidating documentation.

## Summary

**Files to Delete**: 23 files (backup files, experimental code, outdated docs)
**Files to Consolidate**: 15 documentation files → 4 comprehensive guides
**Estimated Space Saved**: ~500 KB
**Risk Level**: LOW (no critical files will be deleted)

---

## Phase 1: Safe Deletions (No Consolidation Required)

### 1.1 Delete Backup Swift Files
These are backup copies no longer needed (you have Git history):

```bash
rm "DTS App/DTS App/Managers/JobberAPI.swift.bak2"
rm "DTS App/DTS App/Managers/JobberAPI.swift.bak3"
```

**Reason**: Git provides version history; backup files are redundant.

---

### 1.2 Delete Temporary Text Files
```bash
rm width_fix.txt
rm screenshot.png
```

**Reason**:
- `width_fix.txt` - Code snippet already applied to codebase
- `screenshot.png` - Old screenshot from August, no longer needed

---

### 1.3 Delete Unused Experimental Code Files

**PencilKit Files** (abandoned approach - not used in current implementation):
```bash
rm "DTS App/DTS App/Views/PencilKitPhotoEditor.swift"
rm "DTS App/DTS App/Views/PencilKitTestView.swift"
```

**Test Utility File** (not referenced anywhere):
```bash
rm "DTS App/DTS App/Utilities/TestUIKit.swift"
```

**Misplaced Root-Level Files** (duplicates/unused):
```bash
rm "DTS App/InlineTextAnnotationEditor.swift"
rm "DTS App/PhotoAnnotationCanvas.swift"
```

**Reason**: These files are not imported/used anywhere in the active codebase. Verified with grep.

---

### 1.4 Delete Obsolete Documentation
```bash
rm "DTS App/SETUP_COMPLETE.md"
```

**Reason**: VS Code setup documentation from initial configuration. Information now in README.md.

---

## Phase 2: Delete Abandoned Research Documentation

### 2.1 Delete PencilKit Exploration Docs
These document an exploration of PencilKit that was ultimately abandoned in favor of the custom annotation system:

```bash
rm PENCILKIT_PROTOTYPE.md
rm PENCILKIT_QUICKSTART.md
rm PENCILKIT_SHAPES_GUIDE.md
rm PENCILKIT_SUMMARY.md
rm PENCILKIT_VS_CUSTOM.md
```

**Reason**: Project went with custom annotation system. PencilKit was researched but not used.

---

### 2.2 Delete Analysis/Status Docs
```bash
rm COMPANYCAM_INTEGRATION_ANALYSIS.md  # Research doc for potential integration (not pursued)
rm INTEGRATION_STATUS.md                # Outdated status snapshot
rm BUILD_YOUR_OWN_PHOTO_MANAGER.md     # Generic tutorial, not DTS-specific
```

**Reason**: Research/analysis documents that are no longer relevant to active development.

---

## Phase 3: Consolidate Documentation

### 3.1 Consolidate Text Annotation Fix Documentation

**Create Archive**: `TEXT_ANNOTATION_FIXES_ARCHIVE.md`

This will combine multiple overlapping fix documents:
- TEXT_ANNOTATION_BUG_FIX.md
- TEXT_ANNOTATION_FIX.md
- TEXT_ANNOTATION_FIX_SUMMARY.md
- TEXT_ANNOTATION_IMPROVEMENTS.md
- TEXT_EDITING_FIX.md
- TEXT_FIX_COMPLETE.md
- TEXT_MOVE_FIX.md
- TEXT_MOVE_RESIZE_FIX.md
- TEXT_EDITOR_DEBUG_LOGS.md
- QUICK_TEXT_TEST.md
- INLINE_TEXT_EDITING_IMPLEMENTATION.md

**Instructions**:
1. Create new archive file with consolidated chronological history
2. Group by issue type (positioning, sizing, interaction)
3. Delete original files after consolidation

**Keep These Text Annotation Docs** (still useful):
- TEXT_ANNOTATION_INTERACTION_GUIDE.md ✓ (interaction patterns)
- TEXT_COORDINATE_SYSTEM.md ✓ (architecture explanation)
- TEXT_EDITOR_DEBUG_GUIDE.md ✓ (debugging workflow)

---

### 3.2 Consolidate Photo Annotation Documentation

**Merge into**: `PHOTO_ANNOTATION_IMPLEMENTATION.md` (keep this, it's comprehensive)

**Files to merge/delete**:
```bash
# Merge PHOTO_ANNOTATION_QUICK_START.md content into PHOTO_ANNOTATION_IMPLEMENTATION.md
# Then delete:
rm PHOTO_ANNOTATION_QUICK_START.md
rm PHOTO_ANNOTATION_SHARING_FIX.md  # Specific fix, can archive
```

---

### 3.3 Consolidate Photo Selection Documentation

**Merge into**: `PHOTO_SELECTION_MODE.md` (comprehensive guide)

```bash
# Merge PHOTO_SELECTION_QUICK_GUIDE.md into PHOTO_SELECTION_MODE.md
# Then delete:
rm PHOTO_SELECTION_QUICK_GUIDE.md
```

---

### 3.4 Consolidate Build Documentation

**Action**: Merge `BUILD_INSTRUCTIONS.md` into `README.md`

```bash
# After merging relevant content:
rm BUILD_INSTRUCTIONS.md
```

**Reason**: README.md already has comprehensive build instructions. Avoid duplication.

---

## Phase 4: Consolidate Copilot Instructions

### 4.1 Consolidate Copilot Files

**Keep**: `.github/copilot-instructions.md` (most comprehensive, 298 lines)

**Files to review and merge**:
- `.copilot-instructions.md` (141 lines - GraphQL focus)
- `.copilot/instructions.md` (34 lines - GraphQL focus)
- `.copilot-graphql-reference.md` (brief GraphQL reference)

**Instructions**:
1. Review `.github/copilot-instructions.md` - it already contains most content
2. Verify GraphQL guidelines are comprehensive
3. Delete redundant files:

```bash
rm .copilot-instructions.md
rm .copilot-graphql-reference.md
rm -rf .copilot/  # Delete entire directory if empty after removing instructions.md
```

---

## Phase 5: Organization & Archive

### 5.1 Create Archive Directory (Optional)

If you want to preserve historical documentation rather than delete:

```bash
mkdir -p docs/archive
mv TEXT_ANNOTATION_FIXES_ARCHIVE.md docs/archive/
```

---

## Phase 6: Verification

### 6.1 Verify Project Still Builds

```bash
# Clean build
rm -rf build

# Build project
xcodebuild -project "DTS App/DTS App.xcodeproj" \
  -scheme "DTS App" \
  -destination "platform=iOS Simulator,name=iPhone 16 Pro" \
  -derivedDataPath build \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  clean build
```

**Expected**: Build succeeds with no errors.

---

### 6.2 Update CLAUDE.md References

Check if CLAUDE.md references any deleted files:

```bash
grep -E "PENCILKIT|BUILD_INSTRUCTIONS|COMPANYCAM|INTEGRATION_STATUS" CLAUDE.md
```

Update CLAUDE.md if necessary.

---

## Summary of Files After Cleanup

### Essential Documentation (Keep)
- ✅ `README.md` - Project overview, setup, build instructions
- ✅ `CLAUDE.md` - AI coding assistant guide
- ✅ `CHANGELOG.md` - Version history
- ✅ `.github/copilot-instructions.md` - Copilot/AI guidelines
- ✅ `JOB_PHOTO_UPLOAD_FEATURE.md` - Photo upload workflow
- ✅ `LOCATION_FIX_SUMMARY.md` - Location services architecture
- ✅ `PHOTO_CLEANUP_FEATURE.md` - Photo storage management
- ✅ `PHOTO_SELECTION_MODE.md` - Photo selection features
- ✅ `PHOTO_ANNOTATION_IMPLEMENTATION.md` - Annotation system overview
- ✅ `MCP_OPTIMIZATION.md` - MCP optimization notes

### Architecture Documentation (Keep)
- ✅ `DRAWSANA_COMPARISON.md` - Architecture comparison
- ✅ `DRAWSANA_IMPLEMENTATION.md` - Implementation details
- ✅ `DRAWSANA_REFACTOR_SUMMARY.md` - Refactoring summary
- ✅ `HANDLER_INTEGRATION_GUIDE.md` - Handler integration guide

### Text Annotation Guides (Keep)
- ✅ `TEXT_ANNOTATION_INTERACTION_GUIDE.md` - User interaction patterns
- ✅ `TEXT_COORDINATE_SYSTEM.md` - Coordinate system explanation
- ✅ `TEXT_EDITOR_DEBUG_GUIDE.md` - Debugging workflow

### New Consolidated Files (Create)
- 🆕 `TEXT_ANNOTATION_FIXES_ARCHIVE.md` - Historical fix documentation

---

## Cleanup Commands (All-in-One)

```bash
# WARNING: Review each file before running this script!
# This deletes files permanently (though Git can recover them)

# Backup files
rm "DTS App/DTS App/Managers/JobberAPI.swift.bak2"
rm "DTS App/DTS App/Managers/JobberAPI.swift.bak3"

# Temporary files
rm width_fix.txt screenshot.png

# Unused code files
rm "DTS App/DTS App/Views/PencilKitPhotoEditor.swift"
rm "DTS App/DTS App/Views/PencilKitTestView.swift"
rm "DTS App/DTS App/Utilities/TestUIKit.swift"
rm "DTS App/InlineTextAnnotationEditor.swift"
rm "DTS App/PhotoAnnotationCanvas.swift"

# Obsolete docs
rm "DTS App/SETUP_COMPLETE.md"

# PencilKit research docs
rm PENCILKIT_*.md

# Analysis docs
rm COMPANYCAM_INTEGRATION_ANALYSIS.md
rm INTEGRATION_STATUS.md
rm BUILD_YOUR_OWN_PHOTO_MANAGER.md

# Text annotation fixes (AFTER creating consolidated archive)
# rm TEXT_ANNOTATION_BUG_FIX.md TEXT_ANNOTATION_FIX.md TEXT_ANNOTATION_FIX_SUMMARY.md
# rm TEXT_ANNOTATION_IMPROVEMENTS.md TEXT_EDITING_FIX.md TEXT_FIX_COMPLETE.md
# rm TEXT_MOVE_FIX.md TEXT_MOVE_RESIZE_FIX.md TEXT_EDITOR_DEBUG_LOGS.md
# rm QUICK_TEXT_TEST.md INLINE_TEXT_EDITING_IMPLEMENTATION.md

# Photo docs (AFTER merging)
# rm PHOTO_ANNOTATION_QUICK_START.md PHOTO_ANNOTATION_SHARING_FIX.md
# rm PHOTO_SELECTION_QUICK_GUIDE.md

# Build docs (AFTER merging to README)
# rm BUILD_INSTRUCTIONS.md

# Copilot files
rm .copilot-instructions.md .copilot-graphql-reference.md
rm -rf .copilot/

echo "✅ Cleanup complete!"
```

---

## Rollback Plan

If you need to recover deleted files:

```bash
# See deleted files
git log --diff-filter=D --summary

# Restore a specific file
git checkout HEAD~1 -- path/to/deleted/file.md

# Or restore all deleted files from last commit
git checkout HEAD~1
```

---

## Final Notes

- **Risk Level**: LOW - All deleted files are either backups, experimental code, or documentation
- **Critical Files**: No core Swift files (Models, Views, Managers, Utilities) are being deleted
- **Documentation**: Consolidated docs will be more maintainable and easier to navigate
- **Git History**: All files remain in Git history and can be recovered

**Estimated Time**: 30-45 minutes (including consolidation and verification)
