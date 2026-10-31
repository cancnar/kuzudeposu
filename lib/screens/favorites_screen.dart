import 'package:flutter/material.dart';

import '../data.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'detail_screen.dart';
import 'shell.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  Future<List<Ilan>>? _f;

  @override
  void initState() {
    super.initState();
    if (db.auth.currentSession != null) _f = favoriIlanlar();
  }

  void _yenile() => setState(() => _f = favoriIlanlar());

  @override
  Widget build(BuildContext context) {
    if (_f == null) return const GirisIste('Favorilerin burada', 'Beğendiğin ilanları kaydetmek için giriş yap.');
    return FutureBuilder<List<Ilan>>(
      future: _f,
      builder: (context, s) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Favoriler', style: baslik(26)),
            const SizedBox(height: 12),
            if (s.connectionState != ConnectionState.done)
              yukleniyor()
            else if (s.hasError)
              HataKutusu(s.error!, tekrar: _yenile)
            else if (s.data!.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text('Henüz favori ilanın yok. İlan kartındaki kalbe dokunarak ekle.', textAlign: TextAlign.center, style: TextStyle(color: Renk.soluk)),
              )
            else
              for (final i in s.data!)
                IlanKarti(
                  ilan: i,
                  favori: app.favoriler.contains(i.id),
                  onFavori: () async {
                    app.favoriler.remove(i.id);
                    app.yenile();
                    try {
                      await favoriDegistir(i.id, false);
                    } catch (_) {}
                    _yenile();
                  },
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailScreen(ilan: i)));
                    if (mounted) _yenile();
                  },
                ),
          ],
        );
      },
    );
  }
}
