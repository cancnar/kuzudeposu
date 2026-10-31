import 'package:flutter/material.dart';

import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
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

  Future<void> _ilanVer(BuildContext c) async {
    final secim = await showModalBottomSheet<String>(
      context: c,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ne yapmak istiyorsun?', style: baslik(21)),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => Navigator.pop(ctx, 'sat'), child: const Text('Hayvan satıyorum')),
              const SizedBox(height: 4),
              const Text('İlan ver: fotoğraf, fiyat ve bilgilerle.', style: TextStyle(color: Renk.soluk, fontSize: 13)),
              const SizedBox(height: 14),
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), side: const BorderSide(color: Renk.yesil)),
                onPressed: () => Navigator.pop(ctx, 'ara'),
                child: const Text('Hayvan arıyorum'),
              ),
              const SizedBox(height: 4),
              const Text('Talep yayınla: satıcılar sana uygun ilanını önerir.', style: TextStyle(color: Renk.soluk, fontSize: 13)),
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
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
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Renk.cizgi))),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 64,
                child: Row(
                  children: [
                    _oge(context, 0, 'Ana sayfa', Icons.home_outlined, Icons.home),
                    _oge(context, 1, 'Favoriler', Icons.favorite_border, Icons.favorite),
                    Expanded(
                      child: Center(
                        child: Semantics(
                          label: 'İlan ver',
                          button: true,
                          child: GestureDetector(
                            onTap: () => _ilanVer(context),
                            child: Container(
                              width: 52,
                              height: 52,
                              decoration: const BoxDecoration(color: Renk.kiremit, shape: BoxShape.circle),
                              child: const Icon(Icons.add, color: Colors.white, size: 30),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _oge(context, 2, 'Mesajlar', Icons.mail_outline, Icons.mail, rozet: app.okunmamisMesaj),
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
    return Expanded(
      child: InkWell(
        onTap: () {
          app.sekme = i;
          app.yenile();
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(secili ? dolu : ikon, color: secili ? Renk.yesil : Renk.soluk, size: 26),
                if (rozet > 0)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(color: Renk.kiremit, borderRadius: BorderRadius.circular(9)),
                      alignment: Alignment.center,
                      child: Text('$rozet', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
            Text(ad, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: secili ? Renk.yesil : Renk.soluk)),
          ],
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
