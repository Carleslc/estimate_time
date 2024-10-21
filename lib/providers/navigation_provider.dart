import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NavigationProvider with ChangeNotifier {
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  void setIndex(int index) {
    if (_currentIndex != index) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  // TODO: Refactor index to Page (e.g. Page.activeTasks.index)
  // index ahora mismo es un número mágico, debería estar en un enum para que sea más legible.
  // La función puede llamarse entonces navigateToPage(BuildContext, Page).
  // Otra opción es hacerlo con Router y named routes.
  static void navigateToIndex(BuildContext context, int index) {
    if (!context.mounted) return;
    Provider.of<NavigationProvider>(context, listen: false).setIndex(index);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
