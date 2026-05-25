import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/executive/home_screen.dart';
import 'screens/role_select_screen.dart';
import 'screens/staff/add_schedule_screen.dart';
import 'screens/staff/home_screen.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise notifications (permissions, channel setup)
  await NotificationService.init();

  // Load persisted schedules from SQLite (seeds on first run)
  await ApiService().init();

  runApp(const OcenApp());
}

class OcenApp extends StatelessWidget {
  const OcenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OCEN',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('vi', 'VN'),
        Locale('en', 'US'),
      ],
      locale: const Locale('vi', 'VN'),
      initialRoute: '/',
      routes: {
        '/': (_) => const RoleSelectScreen(),
        '/executive': (_) => const ExecutiveHomeScreen(),
        '/staff': (_) => const StaffHomeScreen(),
        '/add-schedule': (_) => const AddScheduleScreen(),
      },
    );
  }
}
