import 'package:flutter/material.dart';

import '../data.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'favorites_screen.dart';
import 'detail_screen.dart';
import 'settings_screens.dart';
import 'shell.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _cikis(BuildContext c) async {
    final ok = await onayIste(c, 'Çıkış yapmak istiyor musun?', 'İlanların yayında kalır. Tekrar girmek için yeni SMS kodu göndereceğiz.', 'Çıkış yap', tehlike: true);
    if (!ok) return;
    app.misafir = false;
    await db.auth.signOut();
  }

  Future<void> _sil(BuildContext c) async {
    final ok = await onayIste(c, 'Hesabını silmek istiyor musun?',
        'Hesabın, ilanların, mesajların ve değerlendirmelerin kalıcı olarak silinir. Bu işlem geri alınamaz.', 'Hesabımı kalıcı olarak sil',
        tehlike: true);
    if (!ok) return;
    try {
      await db.rpc('hesabimi_sil');
      app.misafir = false;
      await db.auth.signOut();
    } catch (e) {
      if (c.mounted) bildir(c, 'Hesap silinemedi: $e (002_ek_ozellikler.sql çalıştırıldı mı?)');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (db.auth.currentSession == null) return const GirisIste('Profilin burada', 'İlan vermek ve mesajlaşmak için giriş yap.');
    final p = app.profil ?? {};
    final ad = (p['full_name'] as String?) ?? '';
    final rol = {'yetistirici': 'Yetiştirici', 'tuccar': 'Tüccar', 'alici': 'Alıcı'}[p['role']] ?? '';
    final tel = maske(db.auth.currentUser?.phone);
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(radius: 32, backgroundColor: Renk.cizgi, child: Text(ad.isEmpty ? '?' : ad.substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Renk.yesil))),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ad, style: baslik(22)),
                    Text('$tel · ${p['ilce'] ?? ''}, ${p['il'] ?? ''}', style: const TextStyle(color: Renk.soluk, fontSize: 13)),
                    Text('✓ Telefonu doğrulanmış · $rol', style: const TextStyle(color: Renk.yesil, fontWeight: FontWeight.w800, fontSize: 13)),
                    if (((p['rating_count'] as num?) ?? 0) > 0)
                      Text('★ ${puanYaz((p['rating_avg'] as num?) ?? 0)} (${p['rating_count']} değerlendirme)', style: const TextStyle(color: yildizRenk, fontWeight: FontWeight.w800, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Renk.cizgi)), color: Colors.white),
          child: Column(
            children: [
              Satir('İlanlarım', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MineScreen()))),
              Satir('Favorilerim', onTap: () {
                app.sekme = 1;
                app.yenile();
              }),
              Satir('Kayıtlı aramalarım', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SavedSearchesScreen()))),
              Satir('Ayarlar', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()))),
              Satir('Yardım ve destek', onTap: () => bildir(context, 'Yardım sayfası yayın öncesi eklenecek')),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)), onPressed: () => _cikis(context), child: const Text('Çıkış yap')),
              TextButton(onPressed: () => _sil(context), child: const Text('Hesabımı sil', style: TextStyle(color: uyariRenk))),
            ],
          ),
        ),
      ],
    );
  }
}

class MineScreen extends StatefulWidget {
  const MineScreen({super.key});

  @override
  State<MineScreen> createState() => _MineScreenState();
}

class _MineScreenState extends State<MineScreen> {
  late Future<List<Ilan>> _f = benimIlanlarim();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('İlanlarım')),
      body: FutureBuilder<List<Ilan>>(
        future: _f,
        builder: (context, s) {
          if (s.connectionState != ConnectionState.done) return yukleniyor();
          if (s.hasError) return HataKutusu(s.error!, tekrar: () => setState(() => _f = benimIlanlarim()));
          final l = s.data!;
          if (l.isEmpty) return const Center(child: Text('Henüz ilan vermedin. Ortadaki + butonuna dokun.', style: TextStyle(color: Renk.soluk)));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final i in l)
                IlanKarti(
                  ilan: i,
                  durumGoster: true,
                  favori: false,
                  onFavori: () => bildir(context, 'Kendi ilanını favoriye ekleyemezsin'),
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailScreen(ilan: i)));
                    if (mounted) setState(() => _f = benimIlanlarim());
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}
