import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  // Required when doing async work before runApp()
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: Replace these two values with the ones from your Supabase
  // dashboard: Settings -> API -> Project URL / anon public key
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_PROJECT_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );

  runApp(const DocumentTrackingApp());
}

class DocumentTrackingApp extends StatelessWidget {
  const DocumentTrackingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Document Tracking System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E3A8A)),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E3A8A),
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E3A8A),
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}
