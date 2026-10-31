import 'package:flutter/material.dart';

import '../main.dart';
import '../theme.dart';

/// Geçici ana ekran: giriş + profil + veri tabanı bağlantısını doğrular.
/// Gerçek ilan listesi Faz 2'de gelecek.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.profil});
  final Map<String, dynamic> profil;

  Future<List<dynamic>> _ilanlar() async {
    final r = await supabase.rpc('search_listings', params: {'p_limit': 20});
    return r as List<dynamic>;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kuzu Deposu'),
        actions: [
          IconButton(
            tooltip: 'Çıkış yap',
            icon: const Icon(Icons.logout),
            onPressed: () => supabase.auth.signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Merhaba ${profil['full_name']}', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('${profil['ilce']}, ${profil['il']}', style: const TextStyle(color: Renk.soluk)),
              const SizedBox(height: 20),
              Expanded(
                child: FutureBuilder<List<dynamic>>(
                  future: _ilanlar(),
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return Text('İlanlar yüklenemedi: ${snap.error}', style: const TextStyle(color: Renk.kiremit));
                    }
                    final liste = snap.data!;
                    if (liste.isEmpty) {
                      return const Center(child: Text('Henüz ilan yok. İlan verme ekranı sıradaki adım.'));
                    }
                    return ListView.builder(
                      itemCount: liste.length,
                      itemBuilder: (_, i) {
                        final l = liste[i]['listing'] as Map<String, dynamic>;
                        return Card(
                          child: ListTile(
                            title: Text('${l['cins']} · ${l['adet']} adet'),
                            subtitle: Text('${l['il']}/${l['ilce']} · ${l['agirlik_kg']} kg'),
                            trailing: Text('${l['toplam_fiyat']} ₺'),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
