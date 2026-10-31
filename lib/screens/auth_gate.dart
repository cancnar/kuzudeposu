import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import 'home_screen.dart';
import 'phone_screen.dart';
import 'profile_setup_screen.dart';

/// Oturum ve profil durumuna göre doğru ekranı gösterir.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  Future<Map<String, dynamic>?>? _profil;
  String? _uid;

  Future<Map<String, dynamic>?> _profilGetir(String uid) {
    return supabase.from('profiles').select().eq('id', uid).maybeSingle();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, _) {
        final oturum = supabase.auth.currentSession;
        if (oturum == null) {
          _uid = null;
          _profil = null;
          return const PhoneScreen();
        }
        if (_uid != oturum.user.id || _profil == null) {
          _uid = oturum.user.id;
          _profil = _profilGetir(_uid!);
        }
        return FutureBuilder<Map<String, dynamic>?>(
          future: _profil,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            if (snap.hasError) {
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Profil yüklenemedi:\n${snap.error}', textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => setState(() => _profil = _profilGetir(_uid!)),
                          child: const Text('Tekrar dene'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            final profil = snap.data;
            if (profil == null) {
              return ProfileSetupScreen(
                onSaved: () => setState(() => _profil = _profilGetir(_uid!)),
              );
            }
            return HomeScreen(profil: profil);
          },
        );
      },
    );
  }
}
