import 'package:flutter/material.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart'; // Sesuaikan path splash screen kamu

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi notifikasi dengan timeout agar splash screen tidak terhenti di Release mode
  try {
    await NotificationService.init().timeout(const Duration(seconds: 3));
  } catch (e) {
    debugPrint('NotificationService timeout/error: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Judul yang tampil pada layar Recent Apps / App Switcher
      title: 'ERP GMUM Mobile',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B4A2E)),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}
