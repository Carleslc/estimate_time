import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'providers/navigation_provider.dart';
import 'providers/project_provider.dart';
import 'providers/task_provider.dart';
import 'screens/home_screen.dart';
import 'services/isar_service.dart';
import 'styles/app_styles.dart';
import 'utils/message.dart';
import 'utils/platform.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa el locale para las fechas
  Intl.defaultLocale = getSystemLocaleName();
  await initializeDateFormatting(Intl.defaultLocale);

  runApp(const EstimateTimeApp());
}

class EstimateTimeApp extends StatefulWidget {
  static const String title = 'EstimateTime';

  const EstimateTimeApp({super.key});

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
        home: const HomeScreen(),
        theme: AppStyles.theme(context),
        debugShowCheckedModeBanner: false,
        routes: NavigationProvider.routes,
        navigatorKey: NavigationProvider.navigatorKey,
        navigatorObservers: [NavigationProvider.routeObserver],
        scaffoldMessengerKey: ShowMessage.scaffoldMessengerKey,
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        supportedLocales: const [
          Locale.fromSubtags(languageCode: 'es', countryCode: 'ES'),
          Locale.fromSubtags(languageCode: 'en'),
        ],
      ),
    );
  }
}
