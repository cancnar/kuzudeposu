import 'package:flutter/material.dart';

import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'detail_screen.dart';
import 'favorites_screen.dart';
import 'home_screen.dart';
import 'messages_screen.dart';
import 'phone_screen.dart';
import 'profile_screen.dart';
import 'sell_screen.dart';
import 'talepler_screen.dart';

/// Alt menülü ana iskelet.
class Shell extends StatelessWidget {
  const Shell({super.key});

  Widget _sayfa(int i) => switch (i) {
        1 => const FavoritesScreen(),
        2 => const MessagesScreen(),
        3 => const ProfileScreen(),
        _ => const SizedBox.shrink(),
      };

  Widget _secenek(BuildContext ctx, String deger, IconData ikon, String baslikYazi, String aciklama, Color zemin, Color ikonRenk) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Semantics(
          button: true,
          label: baslikYazi,
          hint: aciklama,
          excludeSemantics: true,
          onTap: () => Navigator.pop(ctx, deger),
          child: Basma(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.pop(ctx, deger),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: kutu(18),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(color: zemin, borderRadius: BorderRadius.circular(15)),
                      child: Icon(ikon, color: ikonRenk, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(baslikYazi, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(aciklama, style: const TextStyle(fontSize: 14, color: Renk.soluk)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Renk.soluk),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

  Future<void> _ilanVer(BuildContext c) async {
    final secim = await showModalBottomSheet<String>(
      context: c,
      sheetAnimationStyle: Hareket.altSayfa(c),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 14), child: Text('Ne yapmak istiyorsun?', style: baslik(24))),
              _secenek(ctx, 'sat', Icons.photo_camera_outlined, 'Hayvan satıyorum', 'Fotoğraf ve videoyla ilan ver.', Renk.okZemin, Renk.okYazi),
              _secenek(ctx, 'ara', Icons.manage_search, 'Hayvan arıyorum', 'Talep yayınla, satıcılar sana ilan önersin.', Renk.kupe, Renk.murekkep),
              Center(child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç', style: TextStyle(color: Renk.soluk)))),
            ],
          ),
        ),
      ),
    );
    if (secim == null || !c.mounted) return;
    if (secim == 'ara') {
      await talepVerGit(c);
      return;
    }
    if (!await girisGerekli(c)) return;
    if (!c.mounted) return;
    await Navigator.of(c).push(MaterialPageRoute(builder: (_) => const SellScreen()));

  }

  /// Paylaşılan bağlantıdaki ilanı hemen, girişten sonra dönülecek ilanı ise profil hazır olunca bir kez açar.
  void _bekleyeniAc(BuildContext context) {
    String? id = app.paylasilanIlanId;
    if (id != null) {
      app.paylasilanIlanId = null;
    } else if (app.bekleyenIlanId != null && db.auth.currentSession != null && app.profil != null) {
      id = app.bekleyenIlanId;
      app.bekleyenIlanId = null;
    }
    if (id == null) return;
    final ac = id;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailScreen(ilanId: ac)));
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        _bekleyeniAc(context);
        final s = app.sekme;
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                Offstage(offstage: s != 0, child: const HomeScreen()),
                if (s != 0) KeyedSubtree(key: ValueKey('sekme$s${db.auth.currentSession?.user.id}'), child: _sayfa(s)),
              ],
            ),
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(color: Renk.kart.withValues(alpha: 0.96), border: const Border(top: BorderSide(color: Renk.ayrac))),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 62,
                child: Row(
                  children: [
                    _oge(context, 0, 'Ana sayfa', Icons.home_outlined, Icons.home_rounded),
                    _oge(context, 1, 'Favoriler', Icons.favorite_border, Icons.favorite),
                    Expanded(
                      child: Center(
                        child: Semantics(
                          label: 'İlan ver',
                          button: true,
                          excludeSemantics: true,
                          onTap: () => _ilanVer(context),
                          child: Basma(
                            olcek: 0.94,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _ilanVer(context),
                              child: Container(
                                width: 56,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Renk.yesil,
                                  borderRadius: BorderRadius.circular(15),
                                  boxShadow: const [BoxShadow(color: Color(0x662F5D3A), blurRadius: 14, spreadRadius: -6, offset: Offset(0, 6))],
                                ),
                                child: const Icon(Icons.add_rounded, color: Renk.krem, size: 28),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _oge(context, 2, 'Mesajlar', Icons.chat_bubble_outline, Icons.chat_bubble, rozet: app.okunmamisMesaj),
                    _oge(context, 3, 'Profil', Icons.person_outline, Icons.person),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _oge(BuildContext c, int i, String ad, IconData ikon, IconData dolu, {int rozet = 0}) {
    final secili = app.sekme == i;
    final renk = secili ? Renk.yesil : Renk.soluk;
    void sec() {
      app.sekme = i;
      app.yenile();
    }

    return Expanded(
      child: Semantics(
        button: true,
        selected: secili,
        label: rozet > 0 ? '$ad, $rozet okunmamış' : ad,
        excludeSemantics: true,
        onTap: sec,
        child: Basma(
          olcek: 0.94,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: sec,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(secili ? dolu : ikon, color: renk, size: 25),
                    if (rozet > 0)
                      Positioned(
                        right: -9,
                        top: -4,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 18),
                          height: 18,
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(color: Renk.kiremit, borderRadius: BorderRadius.circular(9), border: Border.all(color: Renk.kart, width: 1.5)),
                          alignment: Alignment.center,
                          child: Text('$rozet', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(ad, style: TextStyle(fontSize: 11, fontWeight: secili ? FontWeight.w800 : FontWeight.w700, color: renk)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
/// Giriş yapmamış kullanıcıya gösterilen alan.
class GirisIste extends StatelessWidget {
  const GirisIste(this.baslikYazi, this.aciklama, {super.key});
  final String baslikYazi;
  final String aciklama;
  @override
  Widget build(BuildContext context) => Bos(
        baslikYazi,
        aciklama,
        dugme: 'Telefon numaram ile giriş yap',
        onDugme: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PhoneScreen())),
      );
}
