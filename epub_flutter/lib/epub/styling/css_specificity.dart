class CssSpecificity implements Comparable<CssSpecificity> {
  final int id;
  final int cls;
  final int type;
  final bool important;

  const CssSpecificity({
    this.id = 0,
    this.cls = 0,
    this.type = 0,
    this.important = false,
  });

  factory CssSpecificity.fromSelector(String selector) {
    final clean = selector
        .replaceAll(RegExp(r'::[\w-]+'), '')
        .replaceAll(RegExp(r'[>+~]'), ' ');

    final idCount = RegExp(r'#[\w-]+').allMatches(clean).length;

    final withoutIds = clean.replaceAll(RegExp(r'#[\w-]+'), '');
    final clsCount =
        RegExp(r"""\.[\w-]+|\[[\w\s="'~|^$*]+\]|:[\w-]+(?:\([^)]*\))?""")
            .allMatches(withoutIds)
            .length;

    final withoutIdsAndClasses = withoutIds
        .replaceAll(RegExp(r'\.[\w-]+'), '')
        .replaceAll(RegExp(r"""\[[\w\s="'~|^$*]+\]"""), '')
        .replaceAll(RegExp(r':[\w-]+(?:\([^)]*\))?'), '');
    final typeCount = withoutIdsAndClasses
        .split(RegExp(r'\s+'))
        .where((s) =>
            s.isNotEmpty &&
            RegExp(r'^[a-zA-Z][\w-]*$').hasMatch(s) &&
            s != '*')
        .length;

    return CssSpecificity(id: idCount, cls: clsCount, type: typeCount);
  }

  // Inline styles — represented with a very high id count
  static const inline = CssSpecificity(id: 1000);
  static const zero = CssSpecificity();

  @override
  int compareTo(CssSpecificity other) {
    if (important != other.important) return important ? 1 : -1;
    if (id != other.id) return id.compareTo(other.id);
    if (cls != other.cls) return cls.compareTo(other.cls);
    return type.compareTo(other.type);
  }

  bool operator >(CssSpecificity other) => compareTo(other) > 0;
  bool operator >=(CssSpecificity other) => compareTo(other) >= 0;
}
