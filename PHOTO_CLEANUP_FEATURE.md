# Photo Cleanup Feature - Implementation Summary

## Problem
Test photos from development sessions were appearing in the app and couldn't be deleted. These were leftover photos from October 4-5 testing stored in the app's temporary directory (`tmp/DTS_Photos/`).

## Solution
Added two cleanup mechanisms to help users remove unwanted test photos:

### 1. Photo Library - Clear All Photos
**Location**: Photo Library tab → "Clear All" button (top-left toolbar)

**What it does**:
- Deletes ALL photos from the Photo Library
- Removes photo files from disk
- Removes PhotoRecord entries from database
- Shows confirmation dialog before deleting
- Displays count of photos to be deleted

**Use case**: When you want to completely clear the Photo Library and start fresh

### 2. Quote History - Clean Up Orphaned Photos
**Location**: Quote History → ⋯ menu → Storage Info → "Clean Up Orphaned Photos"

**What it does**:
- Finds photos that are no longer associated with any quote
- Includes test photos and photos from deleted quotes
- Scans both temp directory (`DTS_Photos`) and documents directory
- Shows count of orphaned photos found
- Deletes only orphaned photo files (doesn't affect active quotes)

**Use case**: When you want to clean up old test photos without deleting active quote photos

## Implementation Details

### Files Modified
1. **PhotoLibraryView.swift**
   - Added `showingDeleteConfirmation` state
   - Added "Clear All" button to toolbar (only shows when photos exist)
   - Added `deleteAllPhotos()` function
   - Confirmation alert with photo count

2. **QuoteHistoryView.swift**
   - Added `showingCleanupConfirmation` and `orphanedPhotoCount` state
   - Added "Maintenance" section in Storage Info view
   - Added `findOrphanedPhotos()` function - scans directories for orphaned files
   - Added `cleanupOrphanedPhotos()` function - deletes found orphaned files
   - Confirmation alert showing count of orphaned photos

### Photo Storage Locations
Photos are stored in two directories:
- **Temporary Directory**: `/tmp/DTS_Photos/` - Quote draft photos
- **Documents Directory**: `/Documents/` - Photo Library photos

### Safety Features
- **Confirmation dialogs**: Both features require user confirmation before deleting
- **Photo counts**: Shows exact number of photos to be deleted
- **Smart detection**: Orphaned photo cleanup only removes files not associated with quotes
- **Destructive role**: Buttons marked with red color to indicate destructive action

## How to Use

### To Clear All Photos (Photo Library):
1. Open Photo Library tab
2. Tap "Clear All" button (top-left, red)
3. Confirm deletion
4. All photos will be permanently removed

### To Clean Up Test Photos (Quote History):
1. Open Quote History tab
2. Tap ⋯ menu → Storage Info
3. Scroll to "Maintenance" section
4. Tap "Clean Up Orphaned Photos"
5. Review count of orphaned photos found
6. Confirm cleanup
7. Only orphaned photos will be deleted (active quote photos preserved)

## Technical Notes

### Orphaned Photo Detection
The `findOrphanedPhotos()` function:
1. Collects all valid photo URLs from existing quotes
2. Scans temp directory for `.jpg` files
3. Scans documents directory for `.jpg/.jpeg` files
4. Returns files not found in valid photo set

### Deletion Process
- Uses `FileManager.default.removeItem(at:)` for file deletion
- For Photo Library: Also deletes PhotoRecord from SwiftData database
- For orphaned photos: Only deletes files (no database entries exist)
- Logs each deletion for debugging

## Known Limitations
- Photo Library "Clear All" is irreversible (no undo)
- Orphaned photo cleanup can't recover photos once deleted
- Manual file system cleanup may be needed if app crashes during deletion

## Future Enhancements
- [ ] Add "Undo" functionality for accidental deletions
- [ ] Add photo export before deletion
- [ ] Show storage space freed after cleanup
- [ ] Add automatic cleanup on app launch (configurable)
- [ ] Photo cloud backup integration before deletion

---

**Note**: Always back up important photos before using cleanup features. These operations are permanent and cannot be undone.
