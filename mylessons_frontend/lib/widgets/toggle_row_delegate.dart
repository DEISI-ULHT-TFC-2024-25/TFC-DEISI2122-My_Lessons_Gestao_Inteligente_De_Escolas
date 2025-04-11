import 'package:flutter/material.dart';

class ToggleRowDelegate extends SliverPersistentHeaderDelegate {
  final double minExtentHeight;
  final double maxExtentHeight;
  final Widget child;

  ToggleRowDelegate({
    required this.minExtentHeight,
    required this.maxExtentHeight,
    required this.child,
  });

  @override
  double get minExtent => minExtentHeight;

  @override
  double get maxExtent => maxExtentHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant ToggleRowDelegate oldDelegate) {
    return maxExtentHeight != oldDelegate.maxExtentHeight ||
        minExtentHeight != oldDelegate.minExtentHeight ||
        child != oldDelegate.child;
  }
}
