import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/login_screen.dart';
import 'services/push_service.dart';

Future<void> main() async {
  // Required when doing async work before runApp()
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: Replace these two values with the ones from your Supabase
  // dashboard: Settings -> API -> Project URL / anon public key
  await Supabase.initialize(
    url: 'https://sjipwvbiwbbnqnwjqaoy.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNqaXB3dmJpd2JibnFud2pxYW95Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY2Nzg5NzQsImV4cCI6MjEwMjI1NDk3NH0.EqvXOy39PCZQEKkpbmsTwwXFuY5azpyQfmI-zhXmnxc',
  );

  // Sets up push notifications (Android only): connects to the Firebase
  // project configured via android/app/google-services.json.
  await Firebase.initializeApp();

  // Requests notification permission and sets up the foreground-message
  // handler, so a push shows a banner even while the app is open.
  await PushService.instance.init();

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
