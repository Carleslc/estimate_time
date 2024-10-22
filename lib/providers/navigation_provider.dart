import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum AppPage { activeTasks, projects, archivedTasks }

class NavigationProvider with ChangeNotifier {
  AppPage _currentPage = AppPage.activeTasks;

  AppPage get currentPage => _currentPage;

  void setPage(AppPage page) {
    if (_currentPage != page) {
      _currentPage = page;
      notifyListeners();
    }
  }

  static void navigateToPage(BuildContext context, AppPage page) {
    if (!context.mounted) return;
    context.read<NavigationProvider>().setPage(page);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
