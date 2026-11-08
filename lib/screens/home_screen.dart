import 'dart:async';

import 'package:flutter/material.dart';

import '../data.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'detail_screen.dart';
import 'talepler_screen.dart';
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
                  Basma(
                    olcek: 0.92,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(color: Renk.kart, shape: BoxShape.circle, boxShadow: Golge.hafif),
                      child: IconButton(
                        tooltip: 'Bildirimler',
                        padding: EdgeInsets.zero,
                        onPressed: () async {
                          if (!await girisGerekli(context)) return;
                          if (!context.mounted) return;
                          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                          app.sayaclariYenile();
                        },
                        icon: const Icon(Icons.notifications_none_rounded, color: Renk.murekkep),
                      ),
                    ),
                  ),
                  if (app.okunmamisBildirim > 0)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 20),
                        height: 20,
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(color: Renk.kiremit, borderRadius: BorderRadius.circular(10), border: Border.all(color: Renk.krem, width: 1.5)),
                        alignment: Alignment.center,
                        child: Text('${app.okunmamisBildirim}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          KayanSekme(
            secenekler: const ['İlanlar', 'Alıcı talepleri'],
            secili: app.anaSekme,
            degisti: (v) {
              app.anaSekme = v;
              app.yenile();
            },
          ),
          if (app.anaSekme == 1) ...[
            const SizedBox(height: 12),
            const TaleplerGovdesi(),
          ] else ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), boxShadow: Golge.hafif),
                  child: TextField(
                    controller: _q,
                    onChanged: _aramaDegisti,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Cins, il veya ilçe ara',
                      prefixIcon: const Icon(Icons.search_rounded),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Basma(
                    olcek: 0.94,
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: IconButton.filled(
                        tooltip: aktif.isEmpty ? 'Filtre' : 'Filtre (${aktif.length} etkin)',
                        style: IconButton.styleFrom(backgroundColor: Renk.yesil, foregroundColor: Renk.krem, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(fullscreenDialog: true, builder: (_) => const FilterScreen())),
                        icon: const Icon(Icons.tune_rounded),
                      ),
                    ),
                  ),
                  if (aktif.isNotEmpty)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: altin, shape: BoxShape.circle, border: Border.all(color: Renk.krem, width: 1.5)),
                        child: Text('${aktif.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Renk.murekkep)),
                      ),
                    ),
                ],
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
                        backgroundColor: Renk.okZemin,
                        side: BorderSide.none,
                        shape: const StadiumBorder(),
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
          Text('${liste?.length ?? '…'} ilan · ${f['sirala']}', style: const TextStyle(color: Renk.soluk, fontWeight: FontWeight.w700, fontSize: 13)),
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
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => talepVerGit(context),
                    child: const Text('Ya da alıcı talebi yayınla'),
                  ),
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
        ],
      ),
    );
  }
}

/// İki seçenekli sekme: beyaz gösterge 240 ms güçlü ease-out ile kayar, içerik anında değişir.
class KayanSekme extends StatelessWidget {
  const KayanSekme({super.key, required this.secenekler, required this.secili, required this.degisti});
  final List<String> secenekler;
  final int secili;
  final ValueChanged<int> degisti;

  @override
  Widget build(BuildContext context) {
    final n = secenekler.length;
    final azalt = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Renk.zemin2, borderRadius: BorderRadius.circular(14)),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: Alignment(n == 1 ? 0 : -1 + 2 * secili / (n - 1), 0),
            duration: azalt ? Duration.zero : Hareket.gosterge,
            curve: Hareket.cikis,
            child: FractionallySizedBox(
              widthFactor: 1 / n,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: Renk.kart,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(color: Color(0x1A3A3220), blurRadius: 2, offset: Offset(0, 1)),
                    BoxShadow(color: Color(0x1F3A3220), blurRadius: 8, spreadRadius: -2, offset: Offset(0, 2)),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Row(
            children: [
              for (var k = 0; k < n; k++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: k == secili,
                    label: secenekler[k],
                    excludeSemantics: true,
                    onTap: () => degisti(k),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => degisti(k),
                      child: Center(
                        child: Text(
                          secenekler[k],
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: k == secili ? Renk.murekkep : Renk.soluk),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          ),
        ],
      ),
    );
  }
}
