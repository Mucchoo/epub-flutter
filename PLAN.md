# Plan: Fix Highlight Rendering — Replace String Matching with Char Offset Ranges

## Context
The current approach stores the selected text string and tries to match it against individual `EpubTextNode` fragments at render time. This fails because:
- Each node holds only a small fragment of the chapter (~40 chars)
- The stored highlight string is the full multi-sentence selection
- Neither `text.indexOf(highlight)` nor `highlight.contains(text)` matches across fragment boundaries

The correct model: store **global char offsets** (`startOffset`/`endOffset`) across the entire book's concatenated text. At render time, each chapter's global char range is known from `_chapterCharOffsets`, so overlap is an exact integer range check.

---

## Data Model Change

### `Highlight` model (`lib/data/models/highlight.dart`)
Replace `chapter` with `startOffset` and `endOffset` (global char offsets). Keep `text` for display:
```dart
class Highlight {
  final int? id;
  final int bookId;
  final String text;
  final int startOffset;
  final int endOffset;
}
```

### DB (`lib/data/local/app_database.dart`)
Drop and recreate by deleting the app (dev, no migration needed). Replace `chapter` with `start_offset` and `end_offset` INTEGER columns:
```sql
CREATE TABLE highlights (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id      INTEGER NOT NULL,
  text         TEXT    NOT NULL,
  start_offset INTEGER NOT NULL,
  end_offset   INTEGER NOT NULL
)
```

### `HighlightDao` (`lib/data/local/highlight_dao.dart`)
No interface change — update `toMap`/`fromMap` for the new fields.

---

## Save Time: Compute Char Offsets (`reader_view_model.dart`)

`SelectionArea.onSelectionChanged` only provides plain text — no char offset. Flutter does not expose selection offsets via this API. Offset computation is handled entirely in the ViewModel at highlight-save time using a chapter-scoped text search.

Replace `_addHighlight()`:

1. Get the top-visible chapter index from `_findVisibleChapter()?.$1 ?? 0`
2. Check that chapter and the next one (at most 2 candidates) — the selection must be within the visible area:
   ```dart
   int? foundChapter;
   int localStart = -1;
   for (int i = chapter; i <= (chapter + 1) && i < _state.chapterData.length; i++) {
     final chapterText = _state.chapterData[i]?.nodes.map((n) => n.extractText()).join() ?? '';
     localStart = chapterText.indexOf(_pendingSelection);
     if (localStart != -1) { foundChapter = i; break; }
   }
   ```
3. If `foundChapter == null`, return (selection not found)
4. `startOffset = _chapterCharOffsets[foundChapter] + localStart`
5. `endOffset = startOffset + _pendingSelection.length`
6. Save one `Highlight` with `startOffset`, `endOffset`, `text`

---

## Render Time: Offset-Based Overlap (`reader_screen.dart`)

### `itemBuilder` — compute per-chapter highlight ranges
Each chapter's global char range is `[chapterStart, chapterEnd)` from `_chapterCharOffsets`. Clip each highlight to the chapter's local coordinate space:

```dart
final chapterStart = _chapterCharOffsets[index];
final chapterEnd = index + 1 < _chapterCharOffsets.length
    ? _chapterCharOffsets[index + 1]
    : _totalChars;

final chapterHighlightRanges = <(int, int)>[];
for (final h in state.highlights) {
  if (h.startOffset >= chapterEnd || h.endOffset <= chapterStart) continue;
  final start = (h.startOffset - chapterStart).clamp(0, chapterEnd - chapterStart);
  final end = (h.endOffset - chapterStart).clamp(0, chapterEnd - chapterStart);
  chapterHighlightRanges.add((start, end));
}
```

Note: `_chapterCharOffsets` and `_totalChars` are private to the ViewModel — expose them as getters or pass them into the screen via state.

### Replace `List<String> highlights` with `List<(int, int)> highlightRanges` throughout
Thread through all render methods: `_renderNodes` → `_renderNode` → `_renderParagraph` / `_renderHeading` / `_renderList` / `_renderBlockquote` / `_renderAnchor` → `_renderInlineSpan` → `_buildHighlightedSpan`

### Track cumulative char offset as nodes are walked
`_renderNodes` passes a running `charOffset` (default 0) into each `_renderNode` call, incrementing by `node.extractText().length` after each node. Each block-level render method receives its node's `charOffset` and walks inline children similarly.

Signature changes (representative):
```dart
Widget _renderNodes(..., List<(int, int)> highlightRanges, [int charOffset = 0])
Widget _renderParagraph(EpubParagraphNode node, ..., List<(int, int)> highlightRanges, int charOffset)
InlineSpan _renderInlineSpan(EpubContentNode node, ..., List<(int, int)> highlightRanges, int nodeCharOffset)
```

### `_buildHighlightedSpan` — exact overlap, handles partial overlap at boundaries
```dart
InlineSpan _buildHighlightedSpan(String text, TextStyle? style,
    List<(int, int)> highlightRanges, int nodeCharStart) {
  final nodeCharEnd = nodeCharStart + text.length;
  final highlightStyle = (style ?? const TextStyle()).copyWith(backgroundColor: appHighlight);

  for (final (hlStart, hlEnd) in highlightRanges) {
    if (hlStart >= nodeCharEnd || hlEnd <= nodeCharStart) continue;
    final overlapStart = (hlStart - nodeCharStart).clamp(0, text.length);
    final overlapEnd = (hlEnd - nodeCharStart).clamp(0, text.length);
    return TextSpan(children: [
      if (overlapStart > 0) TextSpan(text: text.substring(0, overlapStart), style: style),
      TextSpan(text: text.substring(overlapStart, overlapEnd), style: highlightStyle),
      if (overlapEnd < text.length) TextSpan(text: text.substring(overlapEnd), style: style),
    ]);
  }
  return TextSpan(text: text, style: style);
}
```

---

## Files Modified
| File | Change |
|---|---|
| `lib/data/models/highlight.dart` | Replace `chapter` with `startOffset`, `endOffset` |
| `lib/data/local/app_database.dart` | Update `highlights` table schema |
| `lib/data/local/highlight_dao.dart` | Update `toMap`/`fromMap` for new fields |
| `lib/screens/reader/reader_ui_state.dart` | No change |
| `lib/screens/reader/reader_view_model.dart` | Rewrite `_addHighlight` to compute global offsets; expose `chapterCharOffsets` and `totalChars` as getters; remove debug prints |
| `lib/screens/reader/reader_screen.dart` | Replace `List<String>` with `List<(int,int)>`, thread char offset through render pipeline, rewrite `_buildHighlightedSpan`, remove debug prints |

---

## Verification
1. Delete app from device (clears old DB), reinstall
2. Select short phrase → Highlight → correct span highlighted
3. Select long multi-paragraph passage → Highlight → all covered nodes highlighted
4. Add second highlight → both render correctly
5. Reopen book → highlights persist and render correctly
