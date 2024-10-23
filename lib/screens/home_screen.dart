import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../providers/navigation_provider.dart';
import '../utils/message.dart';
import 'active_tasks_screen.dart';
import 'archived_tasks_screen.dart';
import 'projects_screen.dart';

class HomeScreen extends StatelessWidget {
  final List<Widget> _screens = [
    ActiveTasksScreen(),
    ProjectsScreen(),
    ArchivedTasksScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);

    return Consumer<NavigationProvider>(
      builder: (_, navigationProvider, __) {
        return Scaffold(
          appBar: AppBar(
            title: Text(EstimateTimeApp.title),
          ),
          body: Theme(
            data: theme.copyWith(
              appBarTheme: AppBarTheme(
                titleTextStyle: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
            ),
            child: _screens[navigationProvider.currentPage.index],
          ),
          bottomNavigationBar: SizedBox(
            height: 70,
            child: BottomNavigationBar(
              currentIndex: navigationProvider.currentPage.index,
              items: [
                BottomNavigationBarItem(
                  icon: Icon(Icons.timer), // Icons.task
                  label: 'Cronómetros',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.folder),
                  label: 'Proyectos',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.archive),
                  label: 'Archivo',
                ),
              ],
              onTap: (index) {
                final selectedPage = AppPage.values[index];
                navigationProvider.setPage(selectedPage);
                ShowMessage.hideCurrentSnackBar(context);
              },
            ),
          ),
        );
      },
    );
  }
}
