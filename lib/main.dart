import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'screens/auth_gate.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabasePublishableKey);
  runApp(const KuzuDeposuApp());
}

final supabase = Supabase.instance.client;

class KuzuDeposuApp extends StatelessWidget {
  const KuzuDeposuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kuzu Deposu',
      debugShowCheckedModeBanner: false,
      theme: kuzuTema(),
      home: const AuthGate(),
    );
  }
}
