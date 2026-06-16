import 'package:html/dom.dart' as dom;

class ComputedStyle {
  final Map<String, String> declared;
  final Map<String, String> inherited;
  final dom.Element element;

  const ComputedStyle({
    required this.declared,
    required this.inherited,
    required this.element,
  });

  String? getValue(String property) =>
      declared[property] ?? inherited[property];

  bool get isHidden =>
      getValue('display') == 'none' || getValue('visibility') == 'hidden';
}

typedef ComputedStyleMap = Map<dom.Element, ComputedStyle>;
