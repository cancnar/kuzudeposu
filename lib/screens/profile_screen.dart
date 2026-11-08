import 'package:flutter/material.dart';

import '../data.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
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
    final puanSayisi = ((p['rating_count'] as num?) ?? 0).toInt();
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Renk.okZemin,
                child: Text(ad.isEmpty ? '?' : ad.substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Renk.okYazi)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ad, style: baslik(24)),
                    Text('$tel · ${p['ilce'] ?? ''}, ${p['il'] ?? ''}', style: const TextStyle(color: Renk.soluk, fontSize: 13)),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.verified_outlined, size: 15, color: Renk.okYazi),
                          const SizedBox(width: 4),
                          Text('Telefonu doğrulanmış${rol.isEmpty ? '' : ' · $rol'}', style: const TextStyle(color: Renk.okYazi, fontWeight: FontWeight.w800, fontSize: 13)),
                        ]),
                        if (puanSayisi > 0)
                          Text('★ ${puanYaz((p['rating_avg'] as num?) ?? 0)} ($puanSayisi değerlendirme)', style: const TextStyle(color: yildizRenk, fontWeight: FontWeight.w800, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Bolum('', [
          Satir('İlanlarım', ikon: Icons.list_alt_rounded, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MineScreen()))),
          Satir('Favorilerim', ikon: Icons.favorite_border, onTap: () {
            app.sekme = 1;
            app.yenile();
          }),
          Satir('Kayıtlı aramalarım', ikon: Icons.bookmark_border, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SavedSearchesScreen()))),
        ]),
        Bolum('', [
          Satir('Ayarlar', ikon: Icons.settings_outlined, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()))),
          Satir('Yardım ve destek', ikon: Icons.help_outline, onTap: () => bildir(context, 'Yardım sayfası yayın öncesi eklenecek')),
        ]),
        Bolum('', [
          Satir('Çıkış yap', ikon: Icons.logout_rounded, renk: Renk.kiremit, onTap: () => _cikis(context)),
        ]),
        const SizedBox(height: 8),
        Center(child: TextButton(onPressed: () => _sil(context), child: const Text('Hesabımı sil', style: TextStyle(color: Renk.soluk, fontSize: 13)))),
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
