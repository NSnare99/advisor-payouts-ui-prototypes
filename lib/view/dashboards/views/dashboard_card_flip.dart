import 'package:flutter/material.dart';
import 'package:rms/view/adaptive_grid.dart';

class DashboardCardFlip extends StatelessWidget {
  final List<Widget> children;
  final String title;
  final Icon icon;
  final void Function() toogleCard;
  const DashboardCardFlip(
      {super.key,
      required this.children,
      required this.title,
      required this.toogleCard,
      this.icon = const Icon(Icons.flip_outlined)});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      shadowColor: Theme.of(context).textTheme.labelLarge?.color,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: AdaptiveGrid(children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  title,
                  style:
                      Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: toogleCard,
                  icon: icon,
                ),
              ),
            ]),
          ),
          ...children
        ],
      ),
    );
  }
}
