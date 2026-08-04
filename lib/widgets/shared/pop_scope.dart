// lib/widgets/pop_scope.dart
import 'package:flutter/material.dart';

class PopScope extends StatelessWidget {
  final Widget child;
  final bool canPop;

  const PopScope({super.key, required this.child, this.canPop = true});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => canPop,
      child: child,
    );
  }
}
