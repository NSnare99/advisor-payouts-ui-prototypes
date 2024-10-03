import 'package:flutter/material.dart';

class Breadcrumbs extends StatelessWidget {
  final List<String> items;
  final ValueChanged<int> onTap;
  const Breadcrumbs({super.key, required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(items.length, (index) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => onTap(index),
              child: Text(
                items[index],
              ),
            ),
            if (index < items.length - 1) ...[
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.grey),
              const SizedBox(width: 8),
            ],
          ],
        );
      }),
    );
  }
}
