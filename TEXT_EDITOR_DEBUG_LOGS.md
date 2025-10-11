# Text Editor Debug Log Guide

## 📝 Log Markers and What They Mean

### Gesture Detection
- `🏁 GESTURE ENDED` - Gesture (tap/drag) has finished
  - Shows which tool is active and if movement was detected

- `✅ TEXT TAP DETECTED` - Confirmed this was a text tool tap without movement
  - Should appear every time you tap with text tool selected

### Text Detection
- `📍 Tap at image coordinates` - Where you tapped in image space

- `🔍 Found text at index` - Result of searching for text at tap location
  - `none` = Empty space (will create new text)
  - `0`, `1`, etc. = Found existing text at that index

### Text Actions

#### Creating New Text
```
✨ CREATING NEW TEXT annotation
   - New text at index: X
   - Total annotations: X
```

#### Selecting Text (First Tap)
```
🎯 SELECTING text at index X
   - selectedTextAnnotationIndex: X
```

#### Editing Text (Second Tap)
```
✏️ ENTERING EDIT MODE for index X
   - Text to edit: 'existing text'
   - editingTextAnnotationIndex: X
```

### Overlay Rendering

#### Every Frame Check
```
🔍 OVERLAY EVALUATION - selectedIndex: X, editingIndex: nil
```
- Both `nil` = Nothing should show
- `selectedIndex: 0, editingIndex: nil` = Should show selection handles
- `selectedIndex: nil, editingIndex: 0` = Should show text editor

#### Selection Handles
```
✅ RENDERING SELECTION HANDLES for index X
```
- Blue dotted border, delete button, resize handle should be visible

#### Text Editor
```
✏️ RENDERING TEXT EDITOR for index X
   - Text: 'current text'
   - Font size: 20.0
   - Screen position: (x, y)
```

### Text Editor Component

#### Component Lifecycle
```
👀 TextEditorOverlay APPEARED
   - Initial text: 'Text'
   - Font size: 20.0
⌨️ Attempting to focus text field
   - Focus state set to: true
```

#### Text Changes
```
✏️ Text changed: 'old text' → 'new text'
```
- Should appear as you type

#### Button Actions
```
❌ CANCEL tapped
```
or
```
✅ DONE tapped - saving text: 'final text'
```

## 🔍 Troubleshooting Flowchart

### Issue: Can't create new text
**Look for:**
- `✅ TEXT TAP DETECTED` (should appear)
- `🔍 Found text at index: none` (should be none for empty space)
- `✨ CREATING NEW TEXT annotation` (should appear)

**If missing:** Check if text tool is selected, check if movement threshold is too low

---

### Issue: Can't select existing text
**Look for:**
- `✅ TEXT TAP DETECTED` ✓
- `🔍 Found text at index: X` (should show number, not none)
- `🎯 SELECTING text at index X` (should appear)
- `🔍 OVERLAY EVALUATION - selectedIndex: X` (should update)
- `✅ RENDERING SELECTION HANDLES for index X` (should appear)

**If missing:** Check `findTextAnnotationAt()` function tolerance

---

### Issue: Can't enter edit mode (second tap doesn't work)
**Look for sequence:**
1. First tap: `🎯 SELECTING text at index X`
2. Second tap: `✏️ ENTERING EDIT MODE for index X`
3. Overlay: `✏️ RENDERING TEXT EDITOR for index X`
4. Component: `👀 TextEditorOverlay APPEARED`
5. Focus: `⌨️ Attempting to focus text field`

**If sequence breaks:**
- After step 1, check if `selectedTextAnnotationIndex` is set
- After step 2, check if `editingTextAnnotationIndex` is set
- After step 3, check screen position (might be off-screen)
- After step 4, check if component rendered
- After step 5, check if keyboard appears

---

### Issue: Can't type in text field
**Look for:**
- `👀 TextEditorOverlay APPEARED` ✓
- `⌨️ Attempting to focus text field` ✓
- `Focus state set to: true` ✓
- `✏️ Text changed:` (should appear as you type)

**If no text changes:** Keyboard might not be appearing, or field isn't focused

---

### Issue: Done button doesn't save
**Look for:**
- `✅ DONE tapped - saving text: 'your text'`
- After Done, should see: `🔍 OVERLAY EVALUATION - selectedIndex: X, editingIndex: nil`

**If text not saved:** Check if textInput binding is correct

## 📊 Expected Log Sequence

### Scenario: Create → Select → Edit → Save

```
[Tap 1 - Empty space]
🏁 GESTURE ENDED - Tool: text, Moved: false
✅ TEXT TAP DETECTED
📍 Tap at image coordinates: (100, 200)
🔍 Found text at index: none
✨ CREATING NEW TEXT annotation
   - New text at index: 0
   - Total annotations: 1
🔍 OVERLAY EVALUATION - selectedIndex: 0, editingIndex: nil
✅ RENDERING SELECTION HANDLES for index 0

[Tap 2 - Same text]
🏁 GESTURE ENDED - Tool: text, Moved: false
✅ TEXT TAP DETECTED
📍 Tap at image coordinates: (102, 198)
🔍 Found text at index: 0
✏️ ENTERING EDIT MODE for index 0
   - Text to edit: 'Text'
   - editingTextAnnotationIndex: 0
🔍 OVERLAY EVALUATION - selectedIndex: 0, editingIndex: 0
✏️ RENDERING TEXT EDITOR for index 0
   - Text: 'Text'
   - Font size: 20.0
   - Screen position: (x, y)
👀 TextEditorOverlay APPEARED
   - Initial text: 'Text'
   - Font size: 20.0
⌨️ Attempting to focus text field
   - Focus state set to: true

[User types "Hello"]
✏️ Text changed: 'Text' → 'T'
✏️ Text changed: 'T' → 'Te'
✏️ Text changed: 'Te' → 'Tex'
✏️ Text changed: 'Tex' → 'Text'
✏️ Text changed: 'Text' → 'TextH'
✏️ Text changed: 'TextH' → 'Hello'

[User taps Done]
✅ DONE tapped - saving text: 'Hello'
👋 TextEditorOverlay DISAPPEARED
🔍 OVERLAY EVALUATION - selectedIndex: 0, editingIndex: nil
✅ RENDERING SELECTION HANDLES for index 0
```

## 🎯 Quick Diagnostic Commands

When user reports an issue, ask them to:

1. **"Tap to create text and send the logs"**
   - Look for: `✨ CREATING NEW TEXT`

2. **"Tap the text and send the logs"**
   - Look for: `🎯 SELECTING text` and `✅ RENDERING SELECTION HANDLES`

3. **"Tap it again and send the logs"**
   - Look for: `✏️ ENTERING EDIT MODE` and `👀 TextEditorOverlay APPEARED`

4. **"Try typing and send the logs"**
   - Look for: `✏️ Text changed:` messages

5. **"Tap Done and send the logs"**
   - Look for: `✅ DONE tapped - saving text:`
