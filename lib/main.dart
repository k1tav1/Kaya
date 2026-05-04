import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'services/theme_controller.dart';
import 'services/notification_service.dart';

import 'screens/splash_screen.dart';
import 'screens/chama_choice_screen.dart';
import 'screens/create_chama_screen.dart';
import 'screens/join_login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await Supabase.initialize(
    url: 'https://luvukbciqcjzqcmclyxb.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx1dnVrYmNpcWNqenFjbWNseXhiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjkxMTgyMzIsImV4cCI6MjA4NDY5NDIzMn0.9tUpaWeSls7NZKQHd93wYzRKSbriGbbns8d4BTCueXE',
  );

  await NotificationService.initialize();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeController(),
      child: const KayaApp(),
    ),
  );
}

class KayaApp extends StatelessWidget {
  const KayaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeController = Provider.of<ThemeController>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kaya',
      themeMode: themeController.themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF2E7D32),
        scaffoldBackgroundColor: const Color(0xFFF4F5F7),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFF4CAF50),
        cardColor: const Color(0xFF1E1E1E),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50),
          brightness: Brightness.dark,
          surface: const Color(0xFF1E1E1E),
          background: const Color(0xFF121212),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1E1E1E),
          selectedItemColor: Color(0xFF4CAF50),
          unselectedItemColor: Colors.grey,
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF1E1E1E),
          elevation: 2,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
          titleLarge: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
        dividerColor: Colors.white12,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/choice': (context) => const ChamaChoicePage(),
        '/createChama': (context) => const CreateChamaPage(),
        '/login': (context) => const JoinLoginChamaPage(),
      },
    );
  }
}
