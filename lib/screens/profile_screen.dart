import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'admin_screen.dart';
import 'detail_screen.dart';
import 'metinler_screen.dart';
import 'profile_setup_screen.dart';
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
              ProfilFoto(ad: ad, yol: p['avatar_path'] as String?),
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
        if (p['askida'] == true)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFF7E3DC), borderRadius: BorderRadius.circular(14)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.block_rounded, color: Renk.kiremit),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Hesabın askıya alındı. İlan veremez, mesaj gönderemezsin.${p['askida_neden'] == null ? '' : '\nSebep: ${p['askida_neden']}'}',
                    style: const TextStyle(color: Renk.kiremit, fontWeight: FontWeight.w800),
                  ),
                ),
              ]),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Basma(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileSetupScreen(duzenle: true))),
              icon: const Icon(Icons.edit_outlined, size: 20),
              label: const Text('Profili düzenle'),
            ),
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
        if (app.yonetici)
          Bolum('', [
            Satir('Yönetici paneli', ikon: Icons.insights_outlined, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const YoneticiScreen()))),
          ]),
        Bolum('', [
          Satir('Ayarlar', ikon: Icons.settings_outlined, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()))),
          Satir('Yardım ve destek', ikon: Icons.help_outline, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const YardimScreen()))),
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
          if (s.hasError) return HataKutusu(s.error!, tekrar: () => setState(() { _f = benimIlanlarim(); }));
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
                    if (mounted) setState(() { _f = benimIlanlarim(); });
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Profil fotoğrafı: dokununca galeriden seçip yükler (avatars kovası, kendi klasörü).
class ProfilFoto extends StatefulWidget {
  const ProfilFoto({super.key, required this.ad, this.yol});
  final String ad;
  final String? yol;
  @override
  State<ProfilFoto> createState() => _ProfilFotoState();
}

class _ProfilFotoState extends State<ProfilFoto> {
  bool _yuk = false;

  Future<void> _sec() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 600);
      if (x == null) return;
      setState(() => _yuk = true);
      final uz = x.name.contains('.') ? x.name.split('.').last.toLowerCase() : 'jpg';
      final tip = switch (uz) { 'png' => 'image/png', 'webp' => 'image/webp', _ => 'image/jpeg' };
      await avatarYukle(FotoDosya(await x.readAsBytes(), x.name, tip));
      await app.profilYukle();
      if (mounted) bildir(context, 'Profil fotoğrafın güncellendi');
    } catch (e) {
      if (mounted) bildir(context, 'Fotoğraf yüklenemedi: $e');
    } finally {
      if (mounted) setState(() => _yuk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = avatarUrl(widget.yol);
    return Semantics(
      button: true,
      label: 'Profil fotoğrafını değiştir',
      excludeSemantics: true,
      onTap: _sec,
      child: Basma(
        child: GestureDetector(
          onTap: _yuk ? null : _sec,
          child: Stack(clipBehavior: Clip.none, children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: Renk.okZemin,
              foregroundImage: url == null ? null : NetworkImage(url),
              child: Text(widget.ad.isEmpty ? '?' : widget.ad.substring(0, 1).toUpperCase(),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Renk.okYazi)),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: Renk.yesil, shape: BoxShape.circle, border: Border.all(color: Renk.krem, width: 2)),
                child: _yuk
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.photo_camera_outlined, size: 12, color: Colors.white),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
