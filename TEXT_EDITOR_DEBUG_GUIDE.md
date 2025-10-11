# Text Editor Debug Guide

## 🔍 Comprehensive Logging Added

I've added extensive logging throughout the text annotation flow to help identify exactly where the issue is occurring.

## 📋 What to Do

1. **Open Xcode Console** (or run from terminal to see logs)
2. **Run the app** on iPhone 16 Pro simulator
3. **Open a photo** in the annotation editor
4. **Tap the text tool** (T icon)
5. **Tap on the photo**
6. **Watch the console output** - it will tell you exactly what's happening

## 🎯 Expected Console Output Flow

When everything works correctly, you should see:

```
📝 TEXT TOOL: Gesture started at (x: xxx, y: xxx)
🏁 GESTURE ENDED - Tool: text, Moved: false
✅ TEXT TAP DETECTED - Creating annotation
📍 Image point: (x: xxx, y: xxx)
📐 Container size: (width: xxx, height: xxx)
🖼️ Image size: (width: xxx, height: xxx)
✨ Text annotation created:
   - Index: 0
   - Total annotations: 1
   - editingTextAnnotationIndex: 0
   - showingTextInput: true
🔍 OVERLAY EVALUATION - showingTextInput: true, editingIndex: Optional(0)
✅ OVERLAY CONDITIONS MET - Showing editor for index 0
✅ IMAGE LOADED - Annotation count: 1
📝 Annotation details - Text: 'Tap to edit', Position: (x: xxx, y: xxx)
🎨 INLINE EDITOR RENDERING:
   - Image position: (x: xxx, y: xxx)
   - Screen position: (x: xxx, y: xxx)
   - Image size: (width: xxx, height: xxx)
   - Container size: (width: xxx, height: xxx)
   - Current text: 'Tap to edit'
   - Font size: 20.0
👀 INLINE EDITOR APPEARED
⌨️ Setting keyboard focus
```

## 🐛 Common Issues & What to Look For

### Issue 1: Gesture Not Detected
**Symptoms:**
- No "TEXT TOOL: Gesture started" message
- OR "GESTURE ENDED" shows different tool

**Diagnosis:**
```
❌ Check: Is text tool actually selected?
📝 Look for: "GESTURE ENDED - Tool: arrow" (or other tool)
```

**Fix:** Make sure text tool is selected (blue background on T button)

---

### Issue 2: Movement Detected (False Positive)
**Symptoms:**
- See "MOVEMENT DETECTED" message
- "GESTURE ENDED - Tool: text, Moved: true"
- No "TEXT TAP DETECTED" message

**Diagnosis:**
```
🚶 MOVEMENT DETECTED - Distance: 15px
🏁 GESTURE ENDED - Tool: text, Moved: true
❌ Text annotation NOT created (because hasMoved=true)
```

**Fix:** Tap more precisely, or we can reduce movement threshold from 10px to 5px

---

### Issue 3: Annotation Created But Editor Not Showing
**Symptoms:**
- See "TEXT TAP DETECTED" ✅
- See "Text annotation created" ✅
- See "showingTextInput: true" ✅
- But NO "OVERLAY EVALUATION" message ❌

**Diagnosis:**
```
✅ Text annotation created
❌ Missing: "OVERLAY EVALUATION" log
```

**Problem:** SwiftUI overlay not being evaluated
**Fix:** This is a SwiftUI state update issue - needs different approach

---

### Issue 4: Overlay Evaluated But Conditions Not Met
**Symptoms:**
- See "OVERLAY EVALUATION - showingTextInput: true"
- But NO "OVERLAY CONDITIONS MET" message

**Diagnosis:**
```
🔍 OVERLAY EVALUATION - showingTextInput: true, editingIndex: nil
❌ editingIndex is nil!
```

**Problem:** `editingTextAnnotationIndex` not being set correctly
**Fix:** State variable not updating properly

---

### Issue 5: Editor Shows But Position Is Wrong
**Symptoms:**
- Editor appears but off-screen or wrong location
- See all logs up to "INLINE EDITOR RENDERING"

**Diagnosis:**
```
🎨 INLINE EDITOR RENDERING:
   - Image position: (x: 1500, y: 2000)  ← Valid
   - Screen position: (x: 500, y: -200)  ← OFF SCREEN!
```

**Problem:** Coordinate conversion calculation wrong
**Fix:** Adjust `convertToScreenCoordinates` function

---

### Issue 6: Keyboard Not Appearing
**Symptoms:**
- Editor visible ✅
- But keyboard doesn't show

**Diagnosis:**
```
👀 INLINE EDITOR APPEARED
⌨️ Setting keyboard focus
(no error but keyboard missing)
```

**Problem:** iOS Simulator keyboard not enabled
**Fix:** Press `⌘K` in simulator OR I/O menu → Keyboard → Toggle

---

## 🔬 Additional Debug Commands

### View Current State
When debugging in Xcode, you can inspect:

```swift
// Check these in debugger:
po showingTextInput         // Should be true
po editingTextAnnotationIndex  // Should be 0 (for first text)
po photo.annotations.count   // Should increase by 1
po selectedTool             // Should be .text
```

### Manual Test Sequence

1. **Clean slate:**
   ```
   - Kill app
   - Clear console
   - Restart app
   ```

2. **Single tap test:**
   ```
   - Open photo
   - Tap text tool
   - Single precise tap on photo center
   - Watch console
   ```

3. **Compare with working tool:**
   ```
   - Try arrow tool
   - Draw an arrow
   - Confirm gesture works
   - Switch back to text
   ```

## 📊 Log Analysis Checklist

Go through this checklist based on console output:

- [ ] `📝 TEXT TOOL: Gesture started` - **Gesture recognized**
- [ ] `🏁 GESTURE ENDED - Tool: text, Moved: false` - **Tap detected (not drag)**
- [ ] `✅ TEXT TAP DETECTED` - **Entered text creation code**
- [ ] `✨ Text annotation created` - **Annotation added to array**
- [ ] `showingTextInput: true` - **Flag set correctly**
- [ ] `editingTextAnnotationIndex: 0` - **Index tracked**
- [ ] `🔍 OVERLAY EVALUATION` - **Overlay being evaluated**
- [ ] `✅ OVERLAY CONDITIONS MET` - **Conditions passed**
- [ ] `✅ IMAGE LOADED` - **Photo loaded successfully**
- [ ] `🎨 INLINE EDITOR RENDERING` - **Editor view rendering**
- [ ] `👀 INLINE EDITOR APPEARED` - **Editor onAppear called**
- [ ] `⌨️ Setting keyboard focus` - **Focus attempt made**

**If you get all checkmarks ✅** → Issue is likely keyboard/simulator
**If you stop partway through** → Issue is at that specific step

## 🎬 What to Send Me

After testing, copy the console output and send me:

1. **Full console log** from when you tap the photo
2. **Which checkmark you stop at** from the checklist above
3. **Screenshot** of what you see on screen (if anything)

This will tell me exactly where the flow is breaking!

---

## 🔧 Quick Fixes Based on Common Patterns

### If hasMoved is always true:
```swift
// In PhotoAnnotationEditor.swift, change line ~257:
if distance >= 10 && !hasMoved {  // ← Change 10 to 5
```

### If editingTextAnnotationIndex is nil:
The state variable isn't updating. Check if @State is being reset somewhere.

### If overlay never evaluates:
SwiftUI view body not re-rendering. Try adding `.id(showingTextInput)` to force refresh.

---

**Run the test and send me the console output!** 🚀
