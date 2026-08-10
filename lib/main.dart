import 'package:flutter/material.dart';

import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AreliaSupervisorApp());
}

class AreliaSupervisorApp extends StatelessWidget {
  const AreliaSupervisorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arelia Supervisor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B5CAD),
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}