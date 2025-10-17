# Quick Test Guide - Text Annotation Position Fix

## Run the App

1. **Launch Simulator**:
   ```bash
   open -a Simulator
   ```

2. **Run Task**: "Run on Simulator" from Command Palette

   OR manually:
   ```bash
   cd "DTS App"
   xcrun simctl install 'iPhone 16 Pro' "../build/Build/Products/Debug-iphonesimulator/DTS App.app"
   xcrun simctl launch 'iPhone 16 Pro' "DTS.DTS-App"
   ```

## Quick Test Steps

### Test 1: Center Position
1. Open app → Navigate to quote with photo → Tap "Edit"
2. Select text tool (T icon)
3. **Tap center of image**
4. Check console output - should see:
   ```
   📍 Normalized position (0..1): (0.500, 0.500)  ← or close to 0.5
   ```
5. Text should appear **exactly where you tapped**

### Test 2: Corner Positions
1. Tap **top-left corner** → Text appears there
   - Console: `Normalized position: (~0.1, ~0.1)`
2. Tap **bottom-right corner** → Text appears there
   - Console: `Normalized position: (~0.9, ~0.9)`

### Test 3: Position Persistence
1. Create text at any position
2. Tap "Done" to save
3. **Reopen** the annotation editor
4. **Verify**: Text is in the EXACT same spot
5. Console should show same normalized coordinates

### Test 4: Hit Detection
1. Create text
2. Tap directly on the text
3. Should see console output:
   ```
   🔍 findTextAnnotationAtScreenPoint - screen point: (200, 300)
   ✅ HIT! Returning index 0
   ```
4. Text should get **blue selection border**

### Test 5: Selection → Edit
1. Select text (tap once) → Blue border appears
2. Tap text again → Keyboard should appear
3. Edit text → Save → Position unchanged

## Expected Console Output

When creating text, you should see this flow:

```
✅ TEXT TAP DETECTED
📐 Screen tap: (200.0, 300.0), Container size: (400.0, 600.0), Image size: (380.0, 570.0)
📍 Converted to image coordinates: (2000.0, 3000.0)
📍 Normalized position (0..1): (0.500, 0.500)
✨ CREATING NEW TEXT annotation at normalized: (0.5, 0.5)
   - New text at index: 0
```

## Red Flags 🚩

### ❌ Position Drift
**Problem**: Text appears in different spot after save/reopen
**Check**: Compare normalized coordinates in console - should be identical

### ❌ Can't Select Text
**Problem**: Tapping text doesn't select it
**Check**: Console should show "🔍 findTextAnnotationAtScreenPoint" and hit detection logs

### ❌ Text in Wrong Spot
**Problem**: Text doesn't appear where you tap
**Check**: Verify normalized coords are reasonable (0..1 range)

### ❌ Text Off-Screen
**Problem**: Text partially visible or cut off
**Check**: Normalized coordinates should be between 0.0 and 1.0

## Debug Commands

### View Console Output
In Xcode or VS Code terminal, watch for log messages starting with:
- 📐 (measurement info)
- 📍 (position info)
- ✅ (success)
- 🔍 (search/lookup)
- ❌ (failure)

### Clear Old Annotations
If testing with old annotations (pre-fix), they may be in wrong positions. Create **new** text annotations to test the fix.

## Success Criteria

✅ All tests pass:
- Text appears where tapped
- Position persists after save
- Hit detection works
- Selection and editing work smoothly
- Console shows correct normalized coordinates (0..1 range)

## If Something's Wrong

1. Check console for error messages
2. Verify normalized coordinates are in 0..1 range
3. Test with brand new photo (not old annotations)
4. Check image size in console logs
5. Report findings with console output

---

**Expected Test Time**: 5-10 minutes
**Critical Path**: Test 1 → Test 3 → Test 4 (these are most important)
