import 'package:flutter/material.dart';

import '../../epub/models/epub_toc_item.dart';

class EpubTocDrawer extends StatelessWidget {
  final List<EpubTocItem> tocItems;
  final void Function(String href, String? fragment) onTap;

  const EpubTocDrawer({
    super.key,
    required this.tocItems,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Contents',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              controller: controller,
              children: _buildItems(tocItems, depth: 0),
            ),
          ),
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
