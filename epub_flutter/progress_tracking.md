# Progress Tracking System

This document explains the full data and logic flow for how reading progress is tracked, persisted, and restored in the EPUB reader.

---

## Overview

Progress is tracked on two levels simultaneously:

1. **A percentage** (0.0–1.0) derived from scroll position — used for the visual progress bar in the book library.
2. **A CFI (Canonical Fragment Identifier)** — an EPUB-standard string encoding the exact chapter and DOM node position — used to restore the scroll position when the user reopens a book.

Both values are written to a local SQLite database on every save.

---

## Data Structures

### `EpubProgress` — the in-flight snapshot
```dart
// lib/epub/progress/epub_progress.dart
class EpubProgress {
  final int bookId;
  final String cfi;        // e.g. "epubcfi(/6/4[chapter-1]!/4/6[intro])"
  final double percentage; // e.g. 0.42
  final DateTime savedAt;
}
```
This is a pure value object — it is created when progress is about to be saved and passed to the save callback. It is never stored in app state; it only crosses the wire from `EpubProgressTracker` to the database layer.

---

### `EpubCfi` — the parsed CFI value
```dart
// lib/epub/cfi/epub_cfi.dart
class EpubCfi {
  final int spineIndex;          // CFI step index for this spine item (always even: 2, 4, 6...)
  final String? spineIdAssertion;// manifest `id` for verification, e.g. "chapter-1"
  final List<int> contentSteps;  // DOM step(s) within the chapter, e.g. [6]
  final String? targetIdAssertion; // HTML `id` of the target element, e.g. "intro"
}
```

Serialised to string via `toString()`:
```dart
@override
String toString() {
  // produces: epubcfi(/6/4[chapter-1]!/4/6[intro])
  final spineAssert = spineIdAssertion != null ? '[$spineIdAssertion]' : '';
  final contentPath = contentSteps.map((s) => '/$s').join('');
  final targetAssert = targetIdAssertion != null ? '[$targetIdAssertion]' : '';
  return 'epubcfi(/6/$spineIndex$spineAssert!/4$contentPath$targetAssert)';
}
```

The format follows the EPUB CFI specification:
- `/6` — fixed: the spine element in the OPF document
- `/$spineIndex` — which spine item (1-based, ×2, so item 0 → index 2, item 1 → index 4, …)
- `!` — separator: "step into this document"
- `/4` — fixed: the body element
- `/$contentStep` — which top-level child of body (DOM order, ×2 per element)

---

### `NodeKey` — widget-to-DOM bridge
```dart
// lib/screens/epub_reader/content_renderer.dart
typedef NodeKey = ({GlobalKey key, int domIndex, String? elementId});
```
Every top-level rendered widget in a chapter gets a `NodeKey`. The `GlobalKey` lets the system measure where the widget is on screen at runtime. `domIndex` mirrors the EPUB CFI step number. `elementId` is the HTML `id` attribute (used for `#fragment` links and CFI assertions).

---

### Database schema
```sql
-- Created by AppDatabase (lib/data/local/app_database.dart)
CREATE TABLE books (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  title            TEXT    NOT NULL,
  author           TEXT,
  progress         REAL    NOT NULL DEFAULT 0.0,  -- the percentage, 0.0–1.0
  cover_image_path TEXT,
  file_path        TEXT    NOT NULL,
  cfi              TEXT                            -- the CFI string (added in v2 migration)
);
```

The `cfi` column was added in the v2 migration:
```dart
onUpgrade: (db, oldVersion, newVersion) async {
  if (oldVersion < 2) {
    await db.execute('ALTER TABLE books ADD COLUMN cfi TEXT');
  }
},
```

---

## Component Responsibilities

| Component | Role |
|---|---|
| `EpubProgressTracker` | Listens to scroll events, debounces, triggers save |
| `EpubCfiGenerator` | Converts current scroll position → `EpubCfi` |
| `EpubCfi` | Parses and serialises CFI strings |
| `EpubCfiResolver` | Converts a stored `EpubCfi` back to a scroll target |
| `ContentRenderer` | Assigns `NodeKey`s to rendered widgets |
| `EpubChapterView` | Fires `onKeysReady` once widgets are laid out |
| `EpubReaderScreen` | Orchestrates all components; owns the DB connection |
| `BookDao` | Raw SQL: `updateProgress`, `saveCfi`, `getCfi` |
| `BookRepositoryImpl` | Thin delegation layer over `BookDao` |
| `BooksNotifier` | Reloads book list (and thus fresh `progress`) after save |

---

## Full Data Flow

### 1. Opening a book

```
BooksScreen._BookCard.onTap
  └─► Navigator.push(EpubReaderScreen(filePath, bookId))
        └─► EpubReaderScreen.initState()
              └─► _loadBook()
```

```dart
// epub_reader_screen.dart
Future<void> _loadBook() async {
  // (a) Fetch stored CFI from DB before loading the file
  _resumeCfi = await _bookDao.getCfi(widget.bookId);

  // (b) Parse the EPUB file on a background isolate
  final bytes = await File(widget.filePath).readAsBytes();
  final book = await compute(EpubParser.parseBytes, bytes);

  // (c) Filter spine to only linear items
  final chapters = book.spine.where((s) => s.linear).toList();

  // (d) Create the tracker — wires up the scroll listener
  final tracker = EpubProgressTracker(
    bookId: widget.bookId,
    chapters: chapters,
    positionsListener: _positionsListener,
    onSave: _onProgressSave,   // callback into DB
  );

  // (e) Attach a separate listener for the live percentage display
  _positionsListener.itemPositions.addListener(_onPositionsChanged);
  tracker.start();   // begins listening to scroll events

  setState(() { _book = book; _chapters = chapters; _tracker = tracker; });

  // (f) After first frame, restore position if a CFI was found
  if (_resumeCfi != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _restorePosition());
  }
}
```

---

### 2. Scroll → debounce → save

Every scroll event triggers `_onScroll` inside `EpubProgressTracker`:

```dart
// epub_progress_tracker.dart
void _onScroll() {
  _debounce?.cancel();
  _debounce = Timer(const Duration(milliseconds: 800), _save);
}
```

The debounce means `_save()` is only called 800ms after the user **stops** scrolling (any new scroll resets the timer).

```dart
void _save() {
  final positions = positionsListener.itemPositions.value;
  if (positions.isEmpty) return;

  // Generate a CFI from the current visible items
  final cfi = EpubCfiGenerator.generate(
    chapters: chapters,
    positions: positions,
    chapterNodeKeys: _chapterNodeKeys,
  );
  if (cfi == null) return;

  final percentage = _computePercentage(positions);

  onSave(EpubProgress(
    bookId: bookId,
    cfi: cfi.toString(),
    percentage: percentage,
    savedAt: DateTime.now(),
  ));
}
```

`onSave` is the callback wired up in `EpubReaderScreen`:

```dart
// epub_reader_screen.dart
Future<void> _onProgressSave(EpubProgress progress) async {
  await _bookDao.saveCfi(progress.bookId, progress.cfi);
  await _bookDao.updateProgress(progress.bookId, progress.percentage);
}
```

These are two separate SQL `UPDATE` calls:

```dart
// book_dao.dart
Future<void> updateProgress(int id, double progress) async {
  final db = await _db.database;
  await db.update('books', {'progress': progress}, where: 'id = ?', whereArgs: [id]);
}

Future<void> saveCfi(int id, String cfi) async {
  final db = await _db.database;
  await db.update('books', {'cfi': cfi}, where: 'id = ?', whereArgs: [id]);
}
```

---

### 3. Percentage calculation

`_computePercentage` runs both for the live display (via `_onPositionsChanged`) and inside `_save()` before persisting.

```dart
// epub_progress_tracker.dart
double _computePercentage(Iterable<ItemPosition> positions) {
  if (positions.isEmpty || chapters.isEmpty) return 0.0;

  // Find the topmost chapter still partly on screen:
  // smallest itemTrailingEdge that is > 0
  final topItem = positions
      .where((p) => p.itemTrailingEdge > 0)
      .fold<ItemPosition?>(
        null,
        (best, p) => best == null || p.itemTrailingEdge < best.itemTrailingEdge
            ? p
            : best,
      );
  if (topItem == null) return 0.0;

  // How far through the current chapter?
  // itemLeadingEdge is negative when the top of the item is above the viewport.
  final withinItemProgress = topItem.itemLeadingEdge < 0
      ? (-topItem.itemLeadingEdge /
              (topItem.itemTrailingEdge - topItem.itemLeadingEdge))
          .clamp(0.0, 1.0)
      : 0.0;

  // Combine: chapters fully passed + fraction of current chapter
  final baseProgress = topItem.index / chapters.length;
  final itemContribution = withinItemProgress / chapters.length;

  return (baseProgress + itemContribution).clamp(0.0, 1.0);
}
```

**`ItemPosition` semantics** (from `scrollable_positioned_list`):
- `index` — 0-based chapter index in the list
- `itemLeadingEdge` — top of the item relative to viewport height (0.0 = viewport top, 1.0 = viewport bottom; **negative** = item extends above viewport)
- `itemTrailingEdge` — bottom of the item relative to viewport height

**Formula:**
```
baseProgress        = chaptersFullyAboveViewport / totalChapters
withinItemProgress  = how far we've scrolled into the current chapter (0–1)
itemContribution    = withinItemProgress / totalChapters

total = baseProgress + itemContribution   (clamped to 0.0–1.0)
```

Example: 10 chapters, currently halfway through chapter 3 (index 2):
- `baseProgress` = 2 / 10 = 0.20
- `withinItemProgress` = 0.50
- `itemContribution` = 0.50 / 10 = 0.05
- **result** = 0.25 (25%)

---

### 4. CFI generation

`EpubCfiGenerator.generate` converts the live scroll state into a serialisable position:

```dart
// epub_cfi_generator.dart
static EpubCfi? generate({
  required List<EpubSpineItem> chapters,
  required Iterable<ItemPosition> positions,
  required Map<int, List<NodeKey>> chapterNodeKeys,
}) {
  // (a) Same topmost-chapter logic as _computePercentage
  final topItem = positions
      .where((p) => p.itemTrailingEdge > 0)
      .fold<ItemPosition?>( /* smallest trailing edge */ );

  final listIndex = topItem.index;
  final cfiSpineIndex = (listIndex + 1) * 2;   // 0→2, 1→4, 2→6, ...
  final itemrefId = chapters[listIndex].manifestItem.id;

  // (b) Find which rendered widget is at the top of the screen
  final nodeKeys = chapterNodeKeys[listIndex];
  final topNode = _findTopmostVisibleNode(nodeKeys);

  return EpubCfi(
    spineIndex: cfiSpineIndex,
    spineIdAssertion: itemrefId,       // e.g. "chapter-03"
    contentSteps: [topNode.domIndex],  // e.g. [6]
    targetIdAssertion: topNode.elementId, // e.g. "section-2" (may be null)
  );
}
```

`_findTopmostVisibleNode` scans all `NodeKey`s for the current chapter and finds the widget whose top (`box.localToGlobal(Offset.zero).dy`) is at or just above the viewport top (≤ 100px):

```dart
static NodeKey? _findTopmostVisibleNode(List<NodeKey> nodeKeys) {
  double? bestY;
  NodeKey? best;

  for (final node in nodeKeys) {
    final ctx = node.key.currentContext;
    if (ctx == null) continue;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) continue;
    final y = box.localToGlobal(Offset.zero).dy;

    // Keep the one with the greatest y still at/above the fold (y <= 100)
    if (y <= 100) {
      if (bestY == null || y > bestY) {
        bestY = y;
        best = node;
      }
    }
  }

  return best ?? nodeKeys.firstOrNull;
}
```

The 100px threshold is a heuristic: it captures elements that are partially off the top of the screen (so the reader has scrolled past their top edge) while excluding elements that are below the fold. Prefer the greatest y ≤ 100 — that's the element whose top edge is closest to (but still at or above) the visible area top.

---

### 5. NodeKey assignment

`NodeKey`s are assigned when a chapter is rendered. `ContentRenderer.renderWithKeys` assigns one key per top-level node:

```dart
// content_renderer.dart
({Widget widget, List<NodeKey> nodeKeys}) renderWithKeys(List<EpubContentNode> nodes) {
  final keys = <NodeKey>[];
  int elementCounter = 0;

  for (final node in nodes) {
    elementCounter++;
    final domIndex = elementCounter * 2;  // CFI uses even steps
    final key = GlobalKey();
    final elementId = node is EpubAnchorNode ? node.id : null;
    keys.add((key: key, domIndex: domIndex, elementId: elementId));

    final inner = _renderNode(node);
    if (inner != null) widgets.add(KeyedSubtree(key: key, child: inner));
  }
  ...
}
```

`domIndex = counter * 2` mirrors the EPUB CFI convention: even steps refer to element nodes (odd steps refer to text nodes in the full spec, but only elements are tracked here).

After the widget tree is built, `EpubChapterView` fires `onKeysReady` once the frame has been rendered:

```dart
// epub_chapter_view.dart
SchedulerBinding.instance.addPostFrameCallback((_) {
  if (mounted) {
    widget.onKeysReady!(widget.spineIndex, result.nodeKeys);
  }
});
```

`EpubReaderScreen` handles this callback and feeds keys to both its local map and the tracker:

```dart
// epub_reader_screen.dart
void _onChapterKeysReady(int spineIndex, List<NodeKey> keys) {
  _chapterNodeKeys[spineIndex] = keys;
  _tracker?.updateChapterKeys(spineIndex, keys);
}
```

The tracker stores them for use in CFI generation:

```dart
// epub_progress_tracker.dart
void updateChapterKeys(int spineIndex, List<NodeKey> keys) {
  _chapterNodeKeys[spineIndex] = keys;
}
```

---

### 6. Restoring position on book open

When the book opens with a saved CFI, `_restorePosition` is called after the first frame:

```dart
// epub_reader_screen.dart
void _restorePosition() {
  final cfiString = _resumeCfi;
  if (cfiString == null) return;

  // (a) Parse the string back into an EpubCfi object
  final cfi = EpubCfi.parse(cfiString);
  if (cfi == null) return;

  // (b) Resolve to a list index + optional widget key
  final resolved = EpubCfiResolver.resolve(
    cfi: cfi,
    chapters: _chapters,
    chapterNodeKeys: _chapterNodeKeys,
  );
  if (resolved == null) return;

  // (c) Jump the list to the right chapter (instant, no animation)
  _scrollController.jumpTo(index: resolved.spineIndex);

  // (d) If a specific element key was found, fine-scroll to it
  if (resolved.nodeKey != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = resolved.nodeKey!.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx, alignment: 0.0);
    });
  }
}
```

`EpubCfiResolver.resolve` maps the CFI back to a `(spineIndex, GlobalKey?)`:

```dart
// epub_cfi_resolver.dart
static ResolvedPosition? resolve({
  required EpubCfi cfi,
  required List<EpubSpineItem> chapters,
  required Map<int, List<NodeKey>> chapterNodeKeys,
}) {
  // Convert CFI spine index → list index: cfiIndex / 2 - 1
  final listIndex = (cfi.spineIndex ~/ 2) - 1;

  // Correct for chapter reordering using the id assertion
  final correctedIndex = _correctSpineIndex(cfi, chapters, listIndex);

  // Find the target widget key using three fallback strategies:
  // 1. Match by elementId assertion (HTML id attribute)
  // 2. Match by exact domIndex
  // 3. Match by closest domIndex ≤ target (fallback for deleted elements)
  final keys = chapterNodeKeys[correctedIndex];
  GlobalKey? targetKey;
  if (keys != null) {
    if (cfi.targetIdAssertion != null) {
      targetKey = keys.where((k) => k.elementId == cfi.targetIdAssertion)
          .firstOrNull?.key;
    }
    targetKey ??= keys.where((k) => k.domIndex == cfi.contentSteps.last)
        .firstOrNull?.key;
    targetKey ??= keys.where((k) => k.domIndex <= cfi.contentSteps.last)
        .lastOrNull?.key;
  }

  return ResolvedPosition(spineIndex: correctedIndex, nodeKey: targetKey);
}
```

The three-tier key lookup provides resilience: if the exact element is gone (book updated, content restructured), the system falls back to the nearest preceding element rather than losing the position entirely.

---

### 7. Live percentage display

While the user reads, the percentage badge in the bottom-right corner updates in real time via a `ValueNotifier`:

```dart
// epub_reader_screen.dart
void _onPositionsChanged() {
  _progressNotifier.value = _tracker?.currentPercentage ?? 0.0;
}
```

`currentPercentage` re-runs `_computePercentage` on the current positions snapshot without triggering any debounce or DB write:

```dart
// epub_progress_tracker.dart
double get currentPercentage {
  final positions = positionsListener.itemPositions.value;
  return _computePercentage(positions);
}
```

The UI watches it with a `ValueListenableBuilder` — only the percentage text widget rebuilds on scroll, not the whole screen:

```dart
// epub_reader_screen.dart
ValueListenableBuilder<double>(
  valueListenable: _progressNotifier,
  builder: (_, pct, child) => Container(
    // ...
    child: Text('${(pct * 100).round()}%'),
  ),
),
```

---

### 8. Displaying progress in the book library

When the reader is closed, `BooksScreen` reloads the book list, which re-reads `progress` from the DB:

```dart
// books_screen.dart
await Navigator.of(context).push(
  MaterialPageRoute(builder: (_) => EpubReaderScreen(...)),
);
onReturn();  // calls _notifier.loadBooks()
```

```dart
// books_notifier.dart
Future<void> loadBooks() async {
  books = await _repository.getBooks();
  notifyListeners();
}
```

`BookRepositoryImpl.getBooks` maps the raw DB rows into `Book` objects, which carry `progress` as a `double`:

```dart
// book_repository_impl.dart
final books = await _dao.getAllBooks();
return books.map((b) => Book(
  id: b.id,
  title: b.title,
  progress: b.progress,   // 0.0–1.0 from DB
  ...
)).toList();
```

The `_BookCard` widget renders the progress bar and label from this value:

```dart
// books_screen.dart
LinearProgressIndicator(value: book.progress, ...)

final finished = book.progress >= 1.0;
// Shows "Finished" with a checkmark, or "42% Completed"
```

---

## Lifecycle and Cleanup

```dart
// epub_reader_screen.dart
@override
void dispose() {
  _positionsListener.itemPositions.removeListener(_onPositionsChanged);
  _tracker?.stop();      // removes scroll listener + cancels debounce timer
  _progressNotifier.dispose();
  super.dispose();
}
```

`tracker.stop()` both removes the scroll listener and cancels any pending debounce timer:

```dart
// epub_progress_tracker.dart
void stop() {
  positionsListener.itemPositions.removeListener(_onScroll);
  _debounce?.cancel();
}
```

This means if the user closes the book mid-scroll (within 800ms of their last scroll), the in-flight debounce is cancelled and the position is **not** saved. Progress is only saved after the user has been still for 800ms.

---

## End-to-End Flow Summary

```
User scrolls
  │
  ▼
ItemPositionsListener fires
  │
  ├──► _onPositionsChanged()
  │       └─► _progressNotifier.value = currentPercentage
  │               └─► ValueListenableBuilder rebuilds % badge (UI only)
  │
  └──► EpubProgressTracker._onScroll()
          └─► debounce 800ms
                └─► _save()
                      ├─► EpubCfiGenerator.generate(positions, nodeKeys)
                      │     ├─► find topmost chapter in viewport
                      │     ├─► find topmost NodeKey at/above screen top
                      │     └─► return EpubCfi(spineIndex, domIndex, elementId)
                      │
                      ├─► _computePercentage(positions) → 0.0–1.0
                      │
                      └─► onSave(EpubProgress) → _onProgressSave()
                              ├─► BookDao.saveCfi(bookId, cfi.toString())
                              │     └─► UPDATE books SET cfi = ? WHERE id = ?
                              └─► BookDao.updateProgress(bookId, percentage)
                                    └─► UPDATE books SET progress = ? WHERE id = ?

User reopens book
  │
  ▼
_loadBook()
  ├─► BookDao.getCfi(bookId) → "epubcfi(/6/4[ch1]!/4/6[section-2])"
  ├─► EpubCfi.parse(cfiString) → EpubCfi object
  └─► (after first frame) _restorePosition()
        ├─► EpubCfiResolver.resolve(cfi, chapters, nodeKeys)
        │     ├─► listIndex = cfi.spineIndex / 2 - 1
        │     ├─► correct index using spineIdAssertion
        │     └─► find GlobalKey by elementId → domIndex → nearest domIndex
        ├─► _scrollController.jumpTo(index: spineIndex)
        └─► Scrollable.ensureVisible(nodeKey.currentContext)
```
