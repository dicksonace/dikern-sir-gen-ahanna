import 'package:flutter/widgets.dart';

class TabFocus extends InheritedWidget {
  final int index;

  const TabFocus({super.key, required this.index, required super.child});

  static int of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<TabFocus>()?.index ?? 0;
  }

  @override
  bool updateShouldNotify(TabFocus oldWidget) => index != oldWidget.index;
}
