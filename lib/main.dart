import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'data.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/shell.dart';
import 'screens/welcome_screen.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabasePublishableKey);
  await app.baslat();
  db.auth.onAuthStateChange.listen((d) => app.oturumDegisti(d.session));
  app.oturumDegisti(db.auth.currentSession);
  runApp(const KuzuDeposuApp());
}

class KuzuDeposuApp extends StatelessWidget {
  const KuzuDeposuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kuzu Deposu',
      debugShowCheckedModeBanner: false,
      theme: kuzuTema(),
      builder: (context, child) => AnimatedBuilder(
        animation: app,
        builder: (_, __) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(app.yaziOlcek)),
          child: child!,
        ),
      ),
      home: const Kok(),
    );
  }
}

/// Oturum ve profil durumuna göre doğru ekranı seçer.
class Kok extends StatelessWidget {
  const Kok({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        final oturum = db.auth.currentSession;
        if (oturum == null) return app.misafir ? const Shell() : const WelcomeScreen();
        if (!app.profilHazir) return Scaffold(body: yukleniyor());
        if (app.profil == null && app.profilHata != null) {
          return Scaffold(body: HataKutusu('Profil yüklenemedi: ${app.profilHata}', tekrar: app.profilYukle));
        }
        if (app.profil == null) return const ProfileSetupScreen();
        return const Shell();
      },
    );
  }
}
