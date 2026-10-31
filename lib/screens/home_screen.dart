import 'dart:async';

import 'package:flutter/material.dart';

import '../data.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'detail_screen.dart';
import 'filter_screen.dart';
import 'notifications_screen.dart';
import 'phone_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Ilan>? _liste;
  Object? _hata;
  Timer? _t;
  String _imza = '';
  late final TextEditingController _q = TextEditingController(text: app.arama);

  String get _simdi => '${app.filtre.imza}|${app.arama}|${app.ilanSurum}';

  @override
  void initState() {
    super.initState();
    app.addListener(_degisti);
    _yukle();
  }

  @override
  void dispose() {
    app.removeListener(_degisti);
    _t?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _degisti() {
    if (!mounted) return;
    if (_simdi != _imza) {
      _yukle();
    } else {
      setState(() {});
    }
  }

  Future<void> _yukle() async {
    final bu = _simdi;
    _imza = bu;
    setState(() => _hata = null);
    try {
      final l = await ilanAra(app.arama, app.filtre);
      if (!mounted || bu != _imza) return;
      setState(() => _liste = l);
    } catch (e) {
      if (!mounted || bu != _imza) return;
      setState(() {
        _hata = e;
        _liste = null;
      });
    }
  }

  void _aramaDegisti(String v) {
    _t?.cancel();
    _t = Timer(const Duration(milliseconds: 350), () {
      app.arama = v;
      app.yenile();
    });
  }

  Future<void> _favori(Ilan i) async {
    if (!await girisGerekli(context)) return;
    final ekle = !app.favoriler.contains(i.id);
    ekle ? app.favoriler.add(i.id) : app.favoriler.remove(i.id);
    app.yenile();
    try {
      await favoriDegistir(i.id, ekle);
    } catch (e) {
      ekle ? app.favoriler.remove(i.id) : app.favoriler.add(i.id);
      app.yenile();
      if (mounted) bildir(context, 'Favori güncellenemedi: $e');
    }
  }

  Future<void> _kaydet() async {
    if (!await girisGerekli(context)) return;
    final f = app.filtre;
    final baslikYazi = (f['cins'].isNotEmpty ? f['cins'] : (f['tur'] != 'Hepsi' ? f['tur'] : 'Tüm ilanlar')) + (f['il'].isNotEmpty ? ' · ${f['il']}' : '');
    try {
      await aramaKaydet(baslikYazi, f);
      if (mounted) bildir(context, 'Arama kaydedildi, uyan yeni ilan çıkınca haber vereceğiz');
    } catch (e) {
      if (mounted) bildir(context, 'Kaydedilemedi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = app.filtre;
    final aktif = f.aktif();
    final liste = _liste;
    return RefreshIndicator(
      onRefresh: _yukle,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Row(
            children: [
              const Logo(boyut: 34),
              const SizedBox(width: 10),
              Expanded(child: Text('Kuzu Deposu', style: baslik(24))),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton.outlined(
                    tooltip: 'Bildirimler',
                    onPressed: () async {
                      if (!await girisGerekli(context)) return;
                      if (!context.mounted) return;
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                      app.sayaclariYenile();
                    },
                    icon: const Icon(Icons.notifications_none),
                  ),
                  if (app.okunmamisBildirim > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 20),
                        height: 20,
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(color: Renk.kiremit, borderRadius: BorderRadius.circular(10)),
                        alignment: Alignment.center,
                        child: Text('${app.okunmamisBildirim}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _q,
                  onChanged: _aramaDegisti,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(hintText: 'Cins, il veya ilçe ara', prefixIcon: Icon(Icons.search), contentPadding: EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 52), padding: const EdgeInsets.symmetric(horizontal: 16)),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const FilterScreen())),
                child: Text(aktif.isEmpty ? 'Filtre' : 'Filtre (${aktif.length})'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final t in ['Hepsi', ...turSecenekleri])
                  Cip(t, f['tur'] == t, () {
                    app.filtre = f.kopya()..['tur'] = t;
                    app.yenile();
                  }),
              ],
            ),
          ),
          if (aktif.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final a in aktif)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InputChip(
                        label: Text(a.metin),
                        backgroundColor: acikYesil,
                        side: BorderSide.none,
                        labelStyle: const TextStyle(color: Renk.yesil, fontWeight: FontWeight.w700, fontSize: 13),
                        onDeleted: () {
                          app.filtre = f.kopya()..sifirla(a.alanlar);
                          app.yenile();
                        },
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text('${liste?.length ?? '…'} ilan · ${f['sirala']}', style: const TextStyle(color: Renk.soluk, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (_hata != null)
            HataKutusu(_hata!, tekrar: _yukle)
          else if (liste == null)
            yukleniyor()
          else if (liste.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Text('Bu filtrelere uygun ilan yok', style: baslik(22), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  const Text('Filtreleri gevşetmeyi dene.', style: TextStyle(color: Renk.soluk)),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: () {
                      app.filtre = Filtre();
                      app.arama = '';
                      _q.clear();
                      app.yenile();
                    },
                    child: const Text('Tüm filtreleri temizle'),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(onPressed: _kaydet, child: const Text('İlan çıkınca haber ver')),
                ],
              ),
            )
          else
            for (final i in liste)
              IlanKarti(
                ilan: i,
                favori: app.favoriler.contains(i.id),
                onFavori: () => _favori(i),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailScreen(ilan: i))),
              ),
        ],
      ),
    );
  }
}
