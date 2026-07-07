import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../providers/navigation_provider.dart';
import 'active_tasks_screen.dart';
import 'archived_tasks_screen.dart';
import 'projects_screen.dart';

class HomeScreen extends StatelessWidget {
  static const List<Widget> _screens = [
    ActiveTasksScreen(),
    ProjectsScreen(),
    ArchivedTasksScreen(),
  ];

  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);

    return Consumer<NavigationProvider>(
      builder: (_, navigationProvider, __) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(EstimateTimeApp.title),
          ),
          body: Theme(
            data: theme.copyWith(
              appBarTheme: AppBarTheme(
                titleTextStyle: theme.textTheme.headlineSmall?.copyWith(
                  color: theme.colorScheme.secondary,
                ),
              ),
            ),
            child: IndexedStack(
              index: navigationProvider.currentPage.index,
              children: _screens,
            ),
          ),
          bottomNavigationBar: SizedBox(
            height: 70,
            child: BottomNavigationBar(
              currentIndex: navigationProvider.currentPage.index,
              items: const [
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
              },
            ),
          ),
        );
      },
    );
  }
}
