# Plan: Fix Highlight Rendering — Replace String Matching with Char Offset Ranges

## Context
The current approach stores the selected text string and tries to match it against individual `EpubTextNode` fragments at render time. This fails because:
- Each node holds only a small fragment of the chapter (~40 chars)
- The stored highlight string is the full multi-sentence selection
- Neither `text.indexOf(highlight)` nor `highlight.contains(text)` matches across fragment boundaries

The correct model: store the **char start/end offsets** of the highlight within the chapter's concatenated text. At render time each node's position in the chapter is known, so overlap is an exact integer range check.

---

## Data Model Change

### `Highlight` model (`lib/data/models/highlight.dart`)
Replace the single `chapter` field with `startChapter`/`startCharOffset` and `endChapter`/`endCharOffset`. Keep `text` for display:
```dart
class Highlight {
  final int? id;
  final int bookId;
  final String text;
  final int startChapter;
  final int startCharOffset;
  final int endChapter;
  final int endCharOffset;
}
```

### DB (`lib/data/local/app_database.dart`)
Drop and recreate by deleting the app (dev, no migration needed). Replace `chapter` with `start_chapter`, `start_char_offset`, `end_chapter`, `end_char_offset` INTEGER columns:
```sql
CREATE TABLE highlights (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  book_id           INTEGER NOT NULL,
  text              TEXT    NOT NULL,
  start_chapter     INTEGER NOT NULL,
  start_char_offset INTEGER NOT NULL,
  end_chapter       INTEGER NOT NULL,
  end_char_offset   INTEGER NOT NULL
)
```

### `HighlightDao` (`lib/data/local/highlight_dao.dart`)
No interface change — pass through new fields via `toMap`/`fromMap`. Remove the `chapter`-based `where` filter from `getHighlightsForBook` (now queries all highlights for the book).

---

## Save Time: Compute Char Offsets (`reader_view_model.dart`)

The ViewModel already has `_chapterCharOffsets` (List<int>) — the cumulative global char offset of each chapter. Use this to map a global offset to `(chapter, charOffset)`.

Replace `_addHighlight()`:

1. Build the full book text by concatenating all chapter texts in order
2. Find `globalStart = fullText.indexOf(_pendingSelection)` and `globalEnd = globalStart + _pendingSelection.length`
3. If `globalStart == -1`, return (selection not found — shouldn't happen)
4. Map global offsets to chapter + local offset using `_chapterCharOffsets`:
   - `startChapter` = last index `i` where `_chapterCharOffsets[i] <= globalStart`
   - `startCharOffset` = `globalStart - _chapterCharOffsets[startChapter]`
   - `endChapter` = last index `i` where `_chapterCharOffsets[i] < globalEnd`
   - `endCharOffset` = `globalEnd - _chapterCharOffsets[endChapter]`
5. Save one `Highlight` with `startChapter`, `startCharOffset`, `endChapter`, `endCharOffset`, `text`

Add a helper:
```dart
String get _fullBookText => _state.chapterData
    .map((d) => d?.nodes.map((n) => n.extractText()).join() ?? '')
    .join();

(int chapter, int charOffset) _globalOffsetToChapter(int globalOffset) {
  int chapter = 0;
  for (int i = _chapterCharOffsets.length - 1; i >= 0; i--) {
    if (_chapterCharOffsets[i] <= globalOffset) { chapter = i; break; }
  }
  return (chapter, globalOffset - _chapterCharOffsets[chapter]);
}
```

---

## Render Time: Offset-Based Overlap (`reader_screen.dart`)

### `itemBuilder` — compute per-chapter highlight ranges
For each chapter being rendered, compute which char range `[start, end)` within that chapter each highlight covers:

```dart
final chapterHighlightRanges = <(int, int)>[];
for (final h in state.highlights) {
  if (h.startChapter > index || h.endChapter < index) continue;
  final start = h.startChapter == index ? h.startCharOffset : 0;
  final chapterTextLen = data.nodes.map((n) => n.extractText().length).fold(0, (a, b) => a + b);
  final end = h.endChapter == index ? h.endCharOffset : chapterTextLen;
  chapterHighlightRanges.add((start, end));
}
```

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
| `lib/data/models/highlight.dart` | Replace `chapter` with `startChapter`, `startCharOffset`, `endChapter`, `endCharOffset`; add `copyWith` |
| `lib/data/local/app_database.dart` | Update `highlights` table schema |
| `lib/data/local/highlight_dao.dart` | Update `toMap`/`fromMap` for new fields |
| `lib/screens/reader/reader_ui_state.dart` | No change |
| `lib/screens/reader/reader_view_model.dart` | Rewrite `_addHighlight` to compute offsets via snippet search; remove debug prints |
| `lib/screens/reader/reader_screen.dart` | Replace `List<String>` with `List<(int,int)>`, thread char offset through render pipeline, rewrite `_buildHighlightedSpan`, remove debug prints |

---

## Verification
1. Delete app from device (clears old DB), reinstall
2. Select short phrase → Highlight → correct span highlighted
3. Select long multi-paragraph passage → Highlight → all covered nodes highlighted
4. Add second highlight → both render correctly
5. Reopen book → highlights persist and render correctly
