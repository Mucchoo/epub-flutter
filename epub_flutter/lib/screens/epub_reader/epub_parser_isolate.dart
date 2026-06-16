import 'dart:convert';
import 'dart:isolate';

import '../../epub/models/epub_content_node.dart';
import '../../epub/parser/content_parser.dart';
import '../../epub/styling/computed_style.dart';
import '../../epub/styling/css_cascade.dart';
import '../../epub/styling/css_parser.dart';

class ChapterParseRequest {
  final SendPort replyTo;
  final List<int> htmlBytes;
  final String chapterHref;
  final Map<String, List<int>> cssFileBytes;
  final Set<String> knownFilePaths;

  const ChapterParseRequest({
    required this.replyTo,
    required this.htmlBytes,
    required this.chapterHref,
    required this.cssFileBytes,
    required this.knownFilePaths,
  });
}

typedef ChapterParseResult = ({
  List<EpubContentNode> nodes,
  Map<int, ComputedStyle> styleMap,
});

void _isolateEntry(SendPort callerPort) {
  final receivePort = ReceivePort();
  callerPort.send(receivePort.sendPort);

  receivePort.listen((message) {
    if (message is! ChapterParseRequest) return;
    final req = message;

    final parser = ContentParser(
      chapterHref: req.chapterHref,
      knownFilePaths: req.knownFilePaths,
    );
    final nodes = parser.parse(req.htmlBytes);

    final allRules = <CssRule>[];
    for (final cssPath in parser.linkedStylesheetPaths) {
      final cssBytes = req.cssFileBytes[cssPath];
      if (cssBytes == null) continue;
      allRules.addAll(CssParser.parse(utf8.decode(cssBytes), sourceHref: cssPath));
    }
    for (final cssText in parser.embeddedStyleTexts) {
      allRules.addAll(CssParser.parse(cssText));
    }

    final styleMap = CssCascade(allRules).resolveAll(nodes);
    req.replyTo.send((nodes: nodes.stripDom(), styleMap: styleMap));
  });
}

Future<SendPort> spawnChapterParserIsolate() async {
  final receivePort = ReceivePort();
  await Isolate.spawn(_isolateEntry, receivePort.sendPort);
  final sendPort = await receivePort.first as SendPort;
  receivePort.close();
  return sendPort;
}
