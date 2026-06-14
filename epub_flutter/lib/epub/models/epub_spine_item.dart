import 'epub_manifest_item.dart';

class EpubSpineItem {
  final EpubManifestItem manifestItem;
  final bool linear;

  const EpubSpineItem({required this.manifestItem, required this.linear});
}
