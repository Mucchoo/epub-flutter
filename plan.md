# EPUB 3 Flutter Reader — Implementation Plan
**Scope:** Scrolling reader, default font, images supported, no CSS, no font embedding, no progress tracking  
**Target:** Android + iOS  
**Duration:** 3 weeks (15 working days)

---

## Dependencies (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter
  archive: ^3.6.1          # ZIP decoding — NOT an EPUB library
  xml: ^6.5.0              # OPF / NCX / NAV parsing
  html: ^0.15.4            # XHTML content parsing
  path: ^1.9.0             # href resolution
  scrollable_positioned_list: ^0.3.8  # jump to chapter by index
  url_launcher: ^6.3.0     # open external <a href> links
```

No EPUB-specific library is used. `archive`, `xml`, `html`, and `path` are general-purpose utilities.

---

## Project Structure

```
lib/
├── epub/
│   ├── models/
│   │   ├── epub_book.dart          # top-level parsed book
│   │   ├── epub_manifest_item.dart
│   │   ├── epub_spine_item.dart
│   │   ├── epub_toc_item.dart
│   │   └── epub_content_node.dart  # parsed content IR
│   ├── parser/
│   │   ├── epub_parser.dart        # orchestrator
│   │   ├── container_parser.dart   # container.xml
│   │   ├── opf_parser.dart         # manifest + spine + metadata
│   │   ├── nav_parser.dart         # EPUB 3 NAV doc
│   │   ├── ncx_parser.dart         # EPUB 2 NCX fallback
│   │   └── content_parser.dart     # XHTML → EpubContentNode
│   └── rendering/
│       └── content_renderer.dart   # EpubContentNode → Flutter widgets
├── widgets/
│   ├── epub_reader_screen.dart     # main screen
│   ├── epub_chapter_view.dart      # one chapter's widget column
│   └── epub_toc_drawer.dart        # TOC sidebar
└── main.dart
```

---

## Phase 1 — EPUB Parsing (Days 1–3)

### Day 1 — Unzip + container.xml + OPF

**Goal:** Given a file path, produce a fully populated `EpubBook` model.

#### Step 1.1 — Read and unzip

```dart
// epub/parser/epub_parser.dart
import 'package:archive/archive.dart';

class EpubParser {
  static Future<EpubBook> parse(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // Build a normalized path → ArchiveFile lookup map.
    // Normalization: strip leading '/', collapse './', resolve '../'
    final fileMap = <String, ArchiveFile>{};
    for (final file in archive.files) {
      if (file.isFile) {
        fileMap[_normalizePath(file.name)] = file;
      }
    }

    // Validate mimetype (first entry, uncompressed, exact content)
    _validateMimetype(fileMap);

    final opfPath = await _parseContainer(fileMap);
    return _parseOpf(fileMap, opfPath);
  }

  static String _normalizePath(String raw) {
    // Remove leading slash, normalize path separators
    return p.normalize(raw.startsWith('/') ? raw.substring(1) : raw);
  }
}
```

**Key detail:** Build the `fileMap` with normalized keys immediately. Every subsequent lookup goes through this map. Path bugs (leading slash, `./`, `../`) are the #1 source of "resource not found" errors in real EPUBs.

#### Step 1.2 — Parse `META-INF/container.xml`

```dart
// epub/parser/container_parser.dart
static String parseContainer(Map<String, ArchiveFile> fileMap) {
  final file = fileMap['META-INF/container.xml'];
  if (file == null) throw EpubParseException('container.xml not found');

  final doc = XmlDocument.parse(utf8.decode(file.content as List<int>));
  final rootfile = doc.findAllElements('rootfile').firstOrNull;
  if (rootfile == null) throw EpubParseException('No rootfile in container.xml');

  final fullPath = rootfile.getAttribute('full-path');
  if (fullPath == null || fullPath.isEmpty) {
    throw EpubParseException('rootfile missing full-path');
  }
  return _normalizePath(fullPath); // e.g. "OEBPS/content.opf"
}
```

#### Step 1.3 — Parse the OPF (`content.opf`)

```dart
// epub/parser/opf_parser.dart
// Returns EpubBook with manifest, spine, metadata populated.
static EpubBook parseOpf(Map<String, ArchiveFile> fileMap, String opfPath) {
  final opfDir = p.dirname(opfPath); // e.g. "OEBPS"
  final file = fileMap[opfPath] ?? fileMap[_normalizePath(opfPath)];
  final doc = XmlDocument.parse(utf8.decode(file!.content as List<int>));

  // --- Metadata ---
  final metadata = _parseMetadata(doc);

  // --- Manifest ---
  // <item id="ch01" href="Text/chapter1.xhtml" media-type="application/xhtml+xml"
  //       properties="nav"/>
  final manifest = <String, EpubManifestItem>{};
  for (final item in doc.findAllElements('item')) {
    final id = item.getAttribute('id')!;
    final rawHref = item.getAttribute('href')!;
    // Decode URI encoding in href (e.g. spaces as %20)
    final decodedHref = Uri.decodeFull(rawHref);
    // Resolve relative to OPF directory
    final resolvedHref = opfDir.isEmpty
        ? _normalizePath(decodedHref)
        : _normalizePath('$opfDir/$decodedHref');

    manifest[id] = EpubManifestItem(
      id: id,
      href: resolvedHref,
      mediaType: item.getAttribute('media-type') ?? '',
      properties: item.getAttribute('properties') ?? '',
    );
  }

  // --- Spine ---
  // <spine page-progression-direction="ltr">
  //   <itemref idref="ch01" linear="yes"/>
  // </spine>
  final spineElement = doc.findAllElements('spine').first;
  final tocId = spineElement.getAttribute('toc'); // points to NCX (EPUB 2)
  final spine = <EpubSpineItem>[];
  for (final ref in spineElement.findAllElements('itemref')) {
    final idref = ref.getAttribute('idref')!;
    final linear = ref.getAttribute('linear') != 'no';
    final manifestItem = manifest[idref];
    if (manifestItem != null) {
      spine.add(EpubSpineItem(manifestItem: manifestItem, linear: linear));
    }
  }
  // Only keep linear items for reading; non-linear are auxiliary (popups etc.)
  // But keep non-linear in manifest for resource resolution.

  // --- Find NAV and NCX ---
  final navItem = manifest.values
      .where((m) => m.properties.contains('nav'))
      .firstOrNull;
  final ncxItem = tocId != null ? manifest[tocId] : manifest.values
      .where((m) => m.mediaType == 'application/x-dtbncx+xml')
      .firstOrNull;

  return EpubBook(
    metadata: metadata,
    manifest: manifest,
    spine: spine,
    fileMap: fileMap,
    navItem: navItem,
    ncxItem: ncxItem,
    opfDir: opfDir,
  );
}
```

**Edge cases to handle:**
- `href` values with URI encoding (`%20`, `%28`, etc.) — always `Uri.decodeFull()` before path join
- OPF in root (no subdirectory) — `opfDir` will be `'.'`, treat as `''`
- Multiple renditions (rare) — just use the first `rootfile` for now
- Items with missing `id` or `href` — skip with a warning, don't throw

---

### Day 2 — TOC parsing (NAV + NCX fallback)

#### Step 2.1 — EPUB 3 NAV document

The NAV document is an XHTML file. The TOC lives in `<nav epub:type="toc">`.

```dart
// epub/parser/nav_parser.dart
import 'package:html/parser.dart' as htmlParser;

static List<EpubTocItem> parseNav(List<int> bytes, String navHref, String opfDir) {
  final doc = htmlParser.parse(utf8.decode(bytes));

  // Find <nav epub:type="toc"> — the attribute may be namespaced
  final navElements = doc.querySelectorAll('nav');
  final tocNav = navElements.firstWhere(
    (el) => (el.attributes['epub:type'] ?? el.attributes['type'] ?? '')
        .contains('toc'),
    orElse: () => navElements.first, // fallback: just use first nav
  );

  final navDir = p.dirname(navHref); // for resolving relative hrefs
  return _parseOlItems(tocNav.querySelector('ol'), navDir, opfDir);
}

static List<EpubTocItem> _parseOlItems(Element? ol, String navDir, String opfDir) {
  if (ol == null) return [];
  final items = <EpubTocItem>[];
  for (final li in ol.children.where((c) => c.localName == 'li')) {
    final a = li.querySelector('a');
    if (a == null) continue;
    final rawHref = a.attributes['href'] ?? '';
    // Separate fragment: "Text/chapter1.xhtml#section2" → href + fragment
    final uri = Uri.parse(rawHref);
    final resolvedHref = _normalizePath(p.join(navDir, uri.path));
    items.add(EpubTocItem(
      title: a.text.trim(),
      href: resolvedHref,
      fragment: uri.fragment.isEmpty ? null : uri.fragment,
      children: _parseOlItems(li.querySelector('ol'), navDir, opfDir),
    ));
  }
  return items;
}
```

#### Step 2.2 — NCX fallback (EPUB 2 and many real EPUB 3 files)

Many EPUB 3 files still bundle an NCX for compatibility. Use it when no NAV is found.

```dart
// epub/parser/ncx_parser.dart
static List<EpubTocItem> parseNcx(List<int> bytes, String ncxHref) {
  final doc = XmlDocument.parse(utf8.decode(bytes));
  final ncxDir = p.dirname(ncxHref);
  final navMap = doc.findAllElements('navMap').firstOrNull;
  if (navMap == null) return [];
  return _parseNavPoints(navMap.findElements('navPoint'), ncxDir);
}

static List<EpubTocItem> _parseNavPoints(Iterable<XmlElement> points, String dir) {
  return points.map((point) {
    final label = point.findAllElements('text').firstOrNull?.innerText.trim() ?? '';
    final rawSrc = point.findAllElements('content').firstOrNull
        ?.getAttribute('src') ?? '';
    final uri = Uri.parse(rawSrc);
    return EpubTocItem(
      title: label,
      href: _normalizePath(p.join(dir, uri.path)),
      fragment: uri.fragment.isEmpty ? null : uri.fragment,
      children: _parseNavPoints(point.findElements('navPoint'), dir),
    );
  }).toList();
}
```

#### Step 2.3 — Reconcile TOC with spine

Real-world EPUBs sometimes have TOC entries that don't match spine items, or spine items with no TOC entry. After parsing TOC, validate that every `href` points to a real file in `fileMap`. This prevents crashes later.

```dart
List<EpubTocItem> reconcile(List<EpubTocItem> toc, Map<String, ArchiveFile> fileMap) {
  // Remove any TOC items whose href doesn't exist in the archive
  return toc
    .where((item) => fileMap.containsKey(item.href))
    .map((item) => item.copyWith(children: reconcile(item.children, fileMap)))
    .toList();
}
```

---

### Day 3 — XHTML content parsing → IR

Rather than walking the DOM to widgets directly, convert the DOM to an **intermediate representation (IR)** first. This keeps the parser and renderer decoupled and makes testing far easier.

#### The IR model

```dart
// epub/models/epub_content_node.dart
sealed class EpubContentNode {}

class EpubTextNode extends EpubContentNode {
  final String text;
  final TextEmphasis emphasis; // none | bold | italic | boldItalic
  final bool isLink;
  final String? linkHref; // resolved href for <a> tags
  EpubTextNode({required this.text, this.emphasis = TextEmphasis.none,
                this.isLink = false, this.linkHref});
}

class EpubParagraphNode extends EpubContentNode {
  final List<EpubContentNode> children; // inline nodes
  EpubParagraphNode(this.children);
}

class EpubHeadingNode extends EpubContentNode {
  final int level; // 1–6
  final List<EpubContentNode> children;
  EpubHeadingNode({required this.level, required this.children});
}

class EpubImageNode extends EpubContentNode {
  final String resolvedHref; // normalized archive path
  EpubImageNode(this.resolvedHref);
}

class EpubListNode extends EpubContentNode {
  final bool ordered;
  final List<EpubListItemNode> items;
  EpubListNode({required this.ordered, required this.items});
}

class EpubListItemNode extends EpubContentNode {
  final List<EpubContentNode> children;
  EpubListItemNode(this.children);
}

class EpubBlockquoteNode extends EpubContentNode {
  final List<EpubContentNode> children;
  EpubBlockquoteNode(this.children);
}

class EpubLineBreakNode extends EpubContentNode {}
class EpubDividerNode extends EpubContentNode {} // <hr>
```

#### The DOM walker

```dart
// epub/parser/content_parser.dart
import 'package:html/parser.dart' as htmlParser;
import 'package:html/dom.dart' as dom;

class ContentParser {
  final String chapterHref; // e.g. "OEBPS/Text/chapter1.xhtml"
  final Map<String, ArchiveFile> fileMap;

  List<EpubContentNode> parse(List<int> bytes) {
    final doc = htmlParser.parse(utf8.decode(bytes));
    final body = doc.body;
    if (body == null) return [];
    return _parseChildren(body.nodes);
  }

  List<EpubContentNode> _parseChildren(List<dom.Node> nodes) {
    final result = <EpubContentNode>[];
    for (final node in nodes) {
      final parsed = _parseNode(node);
      if (parsed != null) result.add(parsed);
    }
    return result;
  }

  EpubContentNode? _parseNode(dom.Node node) {
    if (node is dom.Text) {
      final text = node.text;
      // Collapse whitespace for inline text nodes
      final collapsed = text.replaceAll(RegExp(r'\s+'), ' ');
      if (collapsed.trim().isEmpty) return null;
      return EpubTextNode(text: collapsed);
    }

    if (node is! dom.Element) return null;
    final tag = node.localName?.toLowerCase() ?? '';

    return switch (tag) {
      'p' || 'div' => EpubParagraphNode(_parseInlineChildren(node.nodes)),
      'h1' => EpubHeadingNode(level: 1, children: _parseInlineChildren(node.nodes)),
      'h2' => EpubHeadingNode(level: 2, children: _parseInlineChildren(node.nodes)),
      'h3' => EpubHeadingNode(level: 3, children: _parseInlineChildren(node.nodes)),
      'h4' => EpubHeadingNode(level: 4, children: _parseInlineChildren(node.nodes)),
      'h5' => EpubHeadingNode(level: 5, children: _parseInlineChildren(node.nodes)),
      'h6' => EpubHeadingNode(level: 6, children: _parseInlineChildren(node.nodes)),
      'ul' => _parseList(node, ordered: false),
      'ol' => _parseList(node, ordered: true),
      'li' => EpubListItemNode(_parseChildren(node.nodes)),
      'blockquote' => EpubBlockquoteNode(_parseChildren(node.nodes)),
      'img' => _parseImage(node),
      'figure' => _parseFigure(node),
      'br' => EpubLineBreakNode(),
      'hr' => EpubDividerNode(),
      // Inline elements that appear at block level — wrap in paragraph
      'span' || 'a' || 'strong' || 'em' || 'b' || 'i' =>
          EpubParagraphNode(_parseInlineChildren([node])),
      // Skip entirely
      'script' || 'style' || 'head' || 'meta' || 'link' => null,
      // Unknown block-level: recurse into children
      _ => _parseChildren(node.nodes).length == 1
          ? _parseChildren(node.nodes).first
          : EpubParagraphNode(_parseChildren(node.nodes)
              .whereType<EpubContentNode>().toList()),
    };
  }

  List<EpubContentNode> _parseInlineChildren(List<dom.Node> nodes) {
    final result = <EpubContentNode>[];
    for (final node in nodes) {
      if (node is dom.Text) {
        final text = node.text.replaceAll(RegExp(r'\s+'), ' ');
        if (text.isNotEmpty) result.add(EpubTextNode(text: text));
      } else if (node is dom.Element) {
        final tag = node.localName?.toLowerCase() ?? '';
        switch (tag) {
          case 'strong' || 'b':
            result.addAll(_parseInlineWithEmphasis(node.nodes, TextEmphasis.bold));
          case 'em' || 'i':
            result.addAll(_parseInlineWithEmphasis(node.nodes, TextEmphasis.italic));
          case 'a':
            final rawHref = node.attributes['href'] ?? '';
            result.add(EpubTextNode(
              text: node.text,
              isLink: true,
              linkHref: _resolveHref(rawHref),
            ));
          case 'img':
            final image = _parseImage(node);
            if (image != null) result.add(image);
          case 'br':
            result.add(EpubLineBreakNode());
          case 'span':
            result.addAll(_parseInlineChildren(node.nodes));
          default:
            result.addAll(_parseInlineChildren(node.nodes));
        }
      }
    }
    return result;
  }

  EpubContentNode? _parseImage(dom.Element el) {
    // Handle both <img src="..."> and <image xlink:href="..."> (SVG)
    final src = el.attributes['src']
        ?? el.attributes['xlink:href']
        ?? el.attributes['href']
        ?? '';
    if (src.isEmpty) return null;
    final resolved = _resolveHref(src);
    // Verify image exists in archive
    if (!fileMap.containsKey(resolved)) {
      // Try stripping fragment (#) if present
      final withoutFragment = resolved.split('#').first;
      if (!fileMap.containsKey(withoutFragment)) return null;
      return EpubImageNode(withoutFragment);
    }
    return EpubImageNode(resolved);
  }

  EpubContentNode? _parseFigure(dom.Element el) {
    // <figure> usually wraps <img> + optional <figcaption>
    final img = el.querySelector('img');
    return img != null ? _parseImage(img) : null;
  }

  EpubListNode _parseList(dom.Element el, {required bool ordered}) {
    final items = el.children
        .where((c) => c.localName == 'li')
        .map((li) => EpubListItemNode(_parseChildren(li.nodes)))
        .toList();
    return EpubListNode(ordered: ordered, items: items);
  }

  String _resolveHref(String rawHref) {
    if (rawHref.startsWith('http://') || rawHref.startsWith('https://')) {
      return rawHref; // external link, return as-is
    }
    final uri = Uri.parse(rawHref);
    final chapterDir = p.dirname(chapterHref);
    return _normalizePath(p.join(chapterDir, uri.path));
  }
}
```

**Critical edge cases in XHTML parsing:**
- `<div>` used as a paragraph (extremely common) — treat like `<p>`
- Nested `<div>` soup — recurse and flatten
- Images referenced as `<image xlink:href>` inside `<svg>` wrappers — check both `src` and `xlink:href`
- XHTML may be malformed — `html` package handles this like a browser (lenient parser)
- Text nodes that are pure whitespace (between block tags) — discard them

---

## Phase 2 — Content Rendering (Days 4–7)

### Day 4 — IR → Flutter widgets

```dart
// epub/rendering/content_renderer.dart
class ContentRenderer {
  final Map<String, ArchiveFile> fileMap;
  final void Function(String href, String? fragment) onLinkTap;

  Widget render(List<EpubContentNode> nodes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: nodes.map(_renderNode).whereType<Widget>().toList(),
    );
  }

  Widget? _renderNode(EpubContentNode node) => switch (node) {
    EpubParagraphNode n => _renderParagraph(n),
    EpubHeadingNode n   => _renderHeading(n),
    EpubImageNode n     => _renderImage(n),
    EpubListNode n      => _renderList(n),
    EpubBlockquoteNode n => _renderBlockquote(n),
    EpubLineBreakNode _ => const SizedBox(height: 8),
    EpubDividerNode _   => const Divider(),
    EpubTextNode n      => _renderParagraph(EpubParagraphNode([n])),
    _                   => null,
  };

  Widget _renderParagraph(EpubParagraphNode node) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text.rich(
        TextSpan(children: node.children.map(_renderInlineSpan).toList()),
      ),
    );
  }

  InlineSpan _renderInlineSpan(EpubContentNode node) {
    if (node is EpubTextNode) {
      if (node.isLink) {
        return TextSpan(
          text: node.text,
          style: const TextStyle(
            color: Colors.blue,
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _handleLinkTap(node.linkHref ?? ''),
        );
      }
      return TextSpan(
        text: node.text,
        style: switch (node.emphasis) {
          TextEmphasis.bold       => const TextStyle(fontWeight: FontWeight.bold),
          TextEmphasis.italic     => const TextStyle(fontStyle: FontStyle.italic),
          TextEmphasis.boldItalic => const TextStyle(
              fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
          TextEmphasis.none       => null,
        },
      );
    }
    if (node is EpubLineBreakNode) return const TextSpan(text: '\n');
    if (node is EpubImageNode) {
      return WidgetSpan(child: _renderImage(node) ?? const SizedBox.shrink());
    }
    return const TextSpan();
  }

  Widget _renderHeading(EpubHeadingNode node) {
    final sizes = {1: 28.0, 2: 24.0, 3: 20.0, 4: 18.0, 5: 16.0, 6: 14.0};
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text.rich(
        TextSpan(children: node.children.map(_renderInlineSpan).toList()),
        style: TextStyle(
          fontSize: sizes[node.level] ?? 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget? _renderImage(EpubImageNode node) {
    final file = fileMap[node.resolvedHref];
    if (file == null) return null; // silently skip missing images
    final bytes = file.content as List<int>;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: double.infinity),
        child: Image.memory(
          Uint8List.fromList(bytes),
          fit: BoxFit.contain,
          // Don't crash on bad image bytes
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Widget _renderList(EpubListNode node) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: node.items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final bullet = node.ordered ? '${index + 1}.' : '•';
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 24, child: Text(bullet)),
              Expanded(child: render(item.children)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _renderBlockquote(EpubBlockquoteNode node) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Colors.grey.shade400, width: 4)),
        color: Colors.grey.shade50,
      ),
      child: render(node.children),
    );
  }

  void _handleLinkTap(String href) {
    if (href.startsWith('http://') || href.startsWith('https://')) {
      url_launcher.launchUrl(Uri.parse(href));
    } else {
      // Internal link: split href and fragment
      final uri = Uri.parse(href);
      onLinkTap(uri.path, uri.fragment.isEmpty ? null : uri.fragment);
    }
  }
}
```

---

### Days 5–6 — Image resolution from archive (the tricky part)

Images in EPUBs are almost always referenced with **relative paths** from the XHTML file's own location. The path resolution must be done at parse time (in `ContentParser._resolveHref`) and stored in `EpubImageNode.resolvedHref` as a normalized key into `fileMap`.

**Common failure patterns to guard against:**

```dart
// Pattern 1: Relative path from chapter dir
// Chapter at: OEBPS/Text/chapter1.xhtml
// <img src="../Images/fig1.jpg">
// Resolves to: OEBPS/Images/fig1.jpg  ✓

// Pattern 2: Absolute path (relative to EPUB root)
// <img src="/OEBPS/Images/fig1.jpg">
// Must strip leading / before lookup  ✓

// Pattern 3: URI-encoded path
// <img src="Images/figure%2001.jpg">
// Must Uri.decodeFull() before resolve  ✓

// Pattern 4: Same-directory reference
// Chapter at: OEBPS/chapter1.xhtml
// <img src="cover.jpg">
// Resolves to: OEBPS/cover.jpg  ✓

// Pattern 5: Fragment in src (rare but seen)
// <img src="images/fig.jpg#xywh=0,0,100,100">
// Must strip fragment before archive lookup  ✓

// Pattern 6: Data URI (base64 embedded image)
// <img src="data:image/png;base64,...">
// Must detect and decode separately  ✓
```

**Data URI handling** (base64 inline images — common in some EPUB generators):

```dart
EpubContentNode? _parseImage(dom.Element el) {
  final src = el.attributes['src'] ?? '';
  if (src.startsWith('data:')) {
    return _parseDataUri(src);
  }
  // ... normal path resolution
}

EpubContentNode? _parseDataUri(String dataUri) {
  // data:image/png;base64,iVBORw0KGgo...
  final commaIndex = dataUri.indexOf(',');
  if (commaIndex == -1) return null;
  final base64Data = dataUri.substring(commaIndex + 1);
  try {
    final bytes = base64Decode(base64Data);
    return EpubInlineImageNode(bytes); // stores Uint8List directly
  } catch (_) {
    return null;
  }
}
```

Add `EpubInlineImageNode` to the IR (holds raw bytes), and handle it in the renderer with `Image.memory` directly — no `fileMap` lookup needed.

**Image caching:** for large EPUBs with many images, `Uint8List.fromList(file.content)` is called per-render. Cache decoded images in a `Map<String, Uint8List>` held by the reader state, keyed by resolved href. Compute on first access, reuse on scroll.

```dart
class ImageCache {
  final Map<String, Uint8List> _cache = {};
  Uint8List? get(String href, Map<String, ArchiveFile> fileMap) {
    return _cache.putIfAbsent(href, () {
      final file = fileMap[href];
      if (file == null) return null;
      return Uint8List.fromList(file.content as List<int>);
    });
  }
}
```

---

### Day 7 — Lazy chapter parsing

Parse each chapter's XHTML **on demand** (when it's about to be scrolled into view), not all at once on load. For a 500-chapter technical book, eager parsing would block the UI for seconds.

```dart
// epub/models/epub_book.dart — add lazy content cache
class EpubBook {
  // ... other fields
  final _contentCache = <int, List<EpubContentNode>>{};

  List<EpubContentNode> getChapterContent(int spineIndex) {
    return _contentCache.putIfAbsent(spineIndex, () {
      final item = spine[spineIndex];
      final file = fileMap[item.manifestItem.href];
      if (file == null) return [];
      return ContentParser(
        chapterHref: item.manifestItem.href,
        fileMap: fileMap,
      ).parse(file.content as List<int>);
    });
  }
}
```

In the UI, trigger `getChapterContent(index)` inside a `FutureBuilder` or use `compute()` to run parsing on a background isolate for large chapters.

---

## Phase 3 — UI (Days 8–10)

### Day 8 — Main reader screen

```dart
// widgets/epub_reader_screen.dart
class EpubReaderScreen extends StatefulWidget {
  final String filePath;
}

class _EpubReaderScreenState extends State<EpubReaderScreen> {
  EpubBook? _book;
  String? _error;
  final ItemScrollController _scrollController = ItemScrollController();
  final ItemPositionsListener _positionsListener = ItemPositionsListener.create();

  @override
  void initState() {
    super.initState();
    _loadBook();
  }

  Future<void> _loadBook() async {
    try {
      // Run parsing in an isolate so the UI doesn't freeze
      final book = await compute(EpubParser.parse, widget.filePath);
      setState(() => _book = book);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return ErrorScreen(message: _error!);
    if (_book == null) return const LoadingScreen();

    return Scaffold(
      appBar: AppBar(
        title: Text(_book!.metadata.title ?? 'Book'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () => _openToc(context),
          ),
        ],
      ),
      body: EpubScrollView(
        book: _book!,
        scrollController: _scrollController,
        positionsListener: _positionsListener,
      ),
    );
  }

  void _openToc(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => EpubTocDrawer(
        tocItems: _book!.toc,
        onTap: (href, fragment) => _navigateTo(href, fragment),
      ),
    );
  }

  void _navigateTo(String href, String? fragment) {
    // Find the spine index for this href
    final spineIndex = _book!.spine.indexWhere(
      (s) => s.manifestItem.href == href,
    );
    if (spineIndex == -1) return;
    Navigator.of(context).pop(); // close TOC
    _scrollController.scrollTo(
      index: spineIndex,
      duration: const Duration(milliseconds: 300),
    );
    // Fragment (#id) scroll within chapter: store target fragment,
    // then handle it in EpubChapterView after the chapter renders.
    // (See Day 9 for fragment targeting detail)
  }
}
```

### Day 9 — Chapter scroll view + TOC drawer

```dart
// widgets/epub_scroll_view.dart
class EpubScrollView extends StatelessWidget {
  final EpubBook book;
  final ItemScrollController scrollController;
  final ItemPositionsListener positionsListener;

  @override
  Widget build(BuildContext context) {
    // Only render linear spine items
    final chapters = book.spine.where((s) => s.linear).toList();

    return ScrollablePositionedList.builder(
      itemCount: chapters.length,
      itemScrollController: scrollController,
      itemPositionsListener: positionsListener,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      itemBuilder: (context, index) {
        return EpubChapterView(
          book: book,
          spineItem: chapters[index],
          spineIndex: index,
          onLinkTap: (href, fragment) {
            // handled by parent via callback
          },
        );
      },
    );
  }
}

// widgets/epub_chapter_view.dart
class EpubChapterView extends StatelessWidget {
  final EpubBook book;
  final EpubSpineItem spineItem;

  @override
  Widget build(BuildContext context) {
    // FutureBuilder allows lazy parse without blocking
    return FutureBuilder<List<EpubContentNode>>(
      future: Future(() => book.getChapterContent(spineIndex)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }
        return ContentRenderer(
          fileMap: book.fileMap,
          onLinkTap: onLinkTap,
        ).render(snapshot.data!);
      },
    );
  }
}
```

**Fragment (`#id`) scroll-within-chapter strategy:**

Fragment navigation (e.g. `chapter1.xhtml#section2`) is the hardest part of the scrolling UI. The simplest approach that works:

1. When parsing each chapter, collect every element with an `id` attribute as `EpubAnchorNode` markers in the IR, in order.
2. In `EpubChapterView`, wrap each widget that corresponds to an `EpubAnchorNode` in a widget with a `GlobalKey`.
3. When navigating to a fragment, after scrolling to the chapter index, do a `post-frame` callback that calls `Scrollable.ensureVisible(context)` on the key of the matching anchor.

This is approximate (not pixel-perfect) but works reliably for standard chapter anchors.

```dart
// TOC drawer
class EpubTocDrawer extends StatelessWidget {
  final List<EpubTocItem> tocItems;
  final void Function(String href, String? fragment) onTap;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (_, controller) => ListView(
        controller: controller,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Contents', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold,
            )),
          ),
          ..._buildItems(tocItems, depth: 0),
        ],
      ),
    );
  }

  List<Widget> _buildItems(List<EpubTocItem> items, {required int depth}) {
    return items.expand((item) => [
      ListTile(
        contentPadding: EdgeInsets.only(left: 16.0 + depth * 16, right: 16),
        title: Text(item.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        onTap: () => onTap(item.href, item.fragment),
      ),
      ..._buildItems(item.children, depth: depth + 1),
    ]).toList();
  }
}
```

### Day 10 — File loading + error handling

The app needs a way to open an EPUB file. Use `file_picker` or receive it via `Share` intent.

```dart
// Add to pubspec.yaml:
// file_picker: ^8.1.2

Future<void> pickAndOpenEpub() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['epub'],
    withData: false, // get path, not bytes, to avoid OOM on large files
  );
  if (result == null || result.files.single.path == null) return;
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => EpubReaderScreen(filePath: result.files.single.path!),
    ),
  );
}
```

**Error handling strategy — never crash, always degrade gracefully:**

```dart
// Parser errors: wrap entire parse in try-catch, show error screen
// Chapter render errors: per-chapter try-catch, show placeholder for that chapter
// Image errors: Image.memory errorBuilder returns SizedBox.shrink()
// Missing files: return empty list / null, log with debugPrint
// Malformed XHTML: html package is lenient, handles it
// Unknown spine item media type: skip non-XHTML items silently
```

---

## Phase 4 — Testing + Edge Cases (Days 11–15)

### Test EPUB corpus

Download and test against these real-world EPUBs that stress different edge cases:

| Source | What it tests |
|---|---|
| Project Gutenberg (any novel) | Baseline reflowable text, NCX-only TOC |
| Standard Ebooks (standardebooks.org) | High-quality EPUB 3 with NAV, clean markup |
| O'Reilly sample EPUBs | Code blocks, tables, complex structure |
| Children's picture books | Large images, minimal text, fixed-layout flags |
| IDPF EPUB 3 samples (github.com/IDPF/epub3-samples) | Official test suite, covers edge cases |

### Edge cases checklist

**Path resolution:**
- [ ] OPF in root directory (no subdirectory)
- [ ] Deep OPF path (`META-INF/../content/OEBPS/package.opf`)
- [ ] Hrefs with `../` that go above OPF dir
- [ ] Windows-style backslash paths (rare but seen)
- [ ] URI-encoded spaces (`%20`) in filenames

**Manifest/Spine:**
- [ ] Non-linear spine items (should be skipped in the scroll view)
- [ ] Spine items with `media-type` other than XHTML (e.g. SVG in spine — skip)
- [ ] Manifest items referenced in spine but missing from archive
- [ ] Duplicate `id` attributes in manifest

**TOC:**
- [ ] NAV doc with no `epub:type="toc"` (fall back to first `<nav>`)
- [ ] Deeply nested TOC (5+ levels deep)
- [ ] TOC entries pointing to missing files
- [ ] NCX-only (no NAV) — EPUB 2 file or old EPUB 3
- [ ] Neither NAV nor NCX (synthesize TOC from spine)

**Content:**
- [ ] XHTML with BOM (UTF-8 BOM: `\xEF\xBB\xBF`) — strip before parsing
- [ ] ISO-8859-1 encoded XHTML (declared in XML prolog) — re-encode
- [ ] Empty chapters (just `<body></body>`)
- [ ] Chapters with only images and no text
- [ ] Very long single paragraphs (no performance issues)
- [ ] `<div>` used for everything instead of semantic tags
- [ ] `<table>` — no support, render a placeholder ("Table not supported") or flatten rows

**Images:**
- [ ] Same image referenced from multiple chapters
- [ ] Image path that only differs by case (`Image.jpg` vs `image.jpg` on case-insensitive FS)
- [ ] JPEG, PNG, GIF (Flutter supports all natively via `Image.memory`)
- [ ] WebP images (supported on Android/iOS via Flutter)
- [ ] SVG images — Flutter does NOT support via `Image.memory`; skip or use `flutter_svg`
- [ ] Very large images (e.g. 5000×7000 px) — add `cacheWidth`/`cacheHeight` to `Image.memory`

**Performance:**
- [ ] 1000-chapter book: ensure lazy loading prevents OOM
- [ ] 100MB EPUB: ensure file reading doesn't block UI (`compute`)
- [ ] Rapid scrolling: ensure `FutureBuilder` handles widget disposal cleanly

### Days 14–15 — Polish

- Add a loading screen with title/author while parsing
- Handle the Android "open with" intent for `.epub` files (add `intent-filter` in `AndroidManifest.xml`)
- Handle iOS document sharing (configure `CFBundleDocumentTypes` in `Info.plist`)
- Add a "back to top" FAB for long chapters
- Verify dark mode works (default Flutter text renders correctly; blockquote `Colors.grey.shade50` needs dark-mode adjustment — use `Theme.of(context)` colors instead of hardcoded ones)

---

## What This Reader Will and Won't Do

### ✅ Works well
- Reflowable novels, short stories, essays, most non-fiction
- Chapter navigation via TOC
- Internal and external links
- Images (JPEG, PNG, GIF, WebP)
- Headings, paragraphs, bold/italic, lists, blockquotes

### ⚠️ Partial / degraded
- Books with heavy CSS layout — text renders but spacing/margins are default Flutter
- Tables — either skip or flatten (no proper table rendering in scope)
- SVG images — only if `flutter_svg` is added; otherwise skipped

### ❌ Not supported (out of scope)
- CSS styling / custom fonts
- Pagination (horizontal page flip)
- Reading position persistence
- MathML
- JavaScript / scripted interactivity
- Audio/video / media overlays
- Fixed-layout EPUBs

---

## Key Decisions Summary

| Decision | Rationale |
|---|---|
| IR (intermediate representation) between parser and renderer | Decouples parsing from UI, enables unit testing of both independently |
| Lazy chapter parsing via `compute` | Prevents UI freeze on large books |
| `scrollable_positioned_list` instead of plain `ListView` | Enables programmatic scroll to chapter by index |
| Normalize all paths immediately in `fileMap` | Single source of truth; prevents the #1 class of "file not found" bugs |
| Degrade gracefully (return null/empty, never throw) in renderer | A bad chapter shouldn't crash the whole book |
| `html` package for XHTML (not `xml`) | Lenient HTML5 parser handles real-world malformed XHTML; `xml` is strict |