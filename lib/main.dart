import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'models/thread.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Init Hive
  await Hive.initFlutter();

  // Register adapters
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ThreadAdapter());
  if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(MessageAdapter());

  // Open boxes
  await Hive.openBox<Thread>('threads');
  await Hive.openBox<Message>('messages');

  // Request mic permission upfront
  await Permission.microphone.request();

  runApp(const OpenClawVoiceApp());
}

class OpenClawVoiceApp extends StatelessWidget {
  const OpenClawVoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OpenClaw Voice',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const HomeScreen(),
      routes: {
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
