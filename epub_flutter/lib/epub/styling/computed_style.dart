class ComputedStyle {
  final Map<String, String> declared;
  final Map<String, String> inherited;

  const ComputedStyle({
    required this.declared,
    required this.inherited,
  });

  String? getValue(String property) =>
      declared[property] ?? inherited[property];

  bool get isHidden =>
      getValue('display') == 'none' || getValue('visibility') == 'hidden';
}

typedef ComputedStyleMap = Map<int, ComputedStyle>;
