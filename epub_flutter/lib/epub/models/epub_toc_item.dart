class EpubTocItem {
  final String title;
  final String href;
  final String? fragment;
  final List<EpubTocItem> children;

  const EpubTocItem({
    required this.title,
    required this.href,
    this.fragment,
    this.children = const [],
  });

  EpubTocItem copyWith({List<EpubTocItem>? children}) {
    return EpubTocItem(
      title: title,
      href: href,
      fragment: fragment,
      children: children ?? this.children,
    );
  }
}
