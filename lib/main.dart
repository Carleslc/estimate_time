import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/navigation_provider.dart';
import 'providers/project_provider.dart';
import 'providers/task_provider.dart';
import 'screens/home_screen.dart';
import 'services/isar_service.dart';
import 'styles/app_styles.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EstimateTimeApp());
}

class EstimateTimeApp extends StatefulWidget {
  static const String title = 'EstimateTime';

  const EstimateTimeApp();

  @override
  State<EstimateTimeApp> createState() => _EstimateTimeAppState();
}

class _EstimateTimeAppState extends State<EstimateTimeApp> {
  final IsarService isarService = IsarService();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<TaskProvider>(
          create: (_) => TaskProvider(isarService),
        ),
        ChangeNotifierProvider<ProjectProvider>(
          create: (_) => ProjectProvider(isarService),
        ),
        ChangeNotifierProvider<NavigationProvider>(
          create: (_) => NavigationProvider(),
        ),
      ],
      child: MaterialApp(
        title: EstimateTimeApp.title,
        home: HomeScreen(),
        theme: AppStyles.theme(context),
      ),
    );
  }
}
