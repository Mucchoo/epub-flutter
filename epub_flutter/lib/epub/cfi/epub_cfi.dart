class EpubCfi {
  final int spineIndex;
  final String? spineIdAssertion;
  final List<int> contentSteps;
  final String? targetIdAssertion;

  const EpubCfi({
    required this.spineIndex,
    this.spineIdAssertion,
    required this.contentSteps,
    this.targetIdAssertion,
  });

  @override
  String toString() {
    final spineAssert = spineIdAssertion != null ? '[$spineIdAssertion]' : '';
    final contentPath = contentSteps.map((s) => '/$s').join('');
    final targetAssert = targetIdAssertion != null ? '[$targetIdAssertion]' : '';
    return 'epubcfi(/6/$spineIndex$spineAssert!/4$contentPath$targetAssert)';
  }

  static EpubCfi? parse(String cfiString) {
    final inner = _extractInner(cfiString);
    if (inner == null) return null;
    try {
      final parts = inner.split('!');
      if (parts.length != 2) return null;

      final spineStep = _parseLastStep(parts[0]);
      if (spineStep == null) return null;
      final contentResult = _parseContentSteps(parts[1]);

      return EpubCfi(
        spineIndex: spineStep.$1,
        spineIdAssertion: spineStep.$2,
        contentSteps: contentResult.$1,
        targetIdAssertion: contentResult.$2,
      );
    } catch (_) {
      return null;
    }
  }

  static String? _extractInner(String cfi) {
    final m = RegExp(r'^epubcfi\((.+)\)$').firstMatch(cfi.trim());
    return m?.group(1);
  }

  // Returns (index, idAssertion?)
  static (int, String?)? _parseLastStep(String path) {
    final stepRegex = RegExp(r'/(\d+)(?:\[([^\]]*)\])?');
    final matches = stepRegex.allMatches(path).toList();
    if (matches.length < 2) return null;
    final last = matches.last;
    return (int.parse(last.group(1)!), last.group(2));
  }

  // Returns (steps, lastIdAssertion?)
  static (List<int>, String?) _parseContentSteps(String path) {
    final stepRegex = RegExp(r'/(\d+)(?:\[([^\]]*)\])?');
    final matches = stepRegex.allMatches(path).toList();
    // Skip /4 (body)
    final steps = matches.skip(1).map((m) => int.parse(m.group(1)!)).toList();
    final lastId = matches.isNotEmpty ? matches.last.group(2) : null;
    return (steps, lastId);
  }
}
