import 'package:flutter/material.dart';

import '../data.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'detail_screen.dart';
import 'phone_screen.dart';
import 'report_screen.dart';

/// Üst bölüm: ad, rol, konum, üyelik, puan ve sayılar. Saf bir bileşen (test edilebilir).
class SaticiBaslik extends StatelessWidget {
  const SaticiBaslik({
    super.key,
    required this.ad,
    required this.rol,
    required this.yer,
    required this.uyelik,
    required this.puan,
    required this.puanSayisi,
    required this.aktifSayi,
    required this.satisSayi,
    required this.dagilim,
  });
  final String ad, rol, yer;
  final DateTime? uyelik;
  final double puan;
  final int puanSayisi, aktifSayi, satisSayi;
  final List<int> dagilim; // 1..5 yıldız adetleri

  Widget _kutu(String deger, String etiket) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: kutu(14.0),
          child: Column(
            children: [
              FittedBox(fit: BoxFit.scaleDown, child: Text(deger, style: baslik(20))),
              const SizedBox(height: 2),
              Text(etiket, style: const TextStyle(color: Renk.soluk, fontSize: 12), textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final toplam = dagilim.fold<int>(0, (a, b) => a + b);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: Renk.cizgi,
                child: Text(ad.isEmpty ? '?' : ad.substring(0, 1).toUpperCase(), style: baslik(28, renk: Renk.yesil)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ad, style: baslik(22)),
                    const SizedBox(height: 2),
                    Text([if (rol.isNotEmpty) rol, yer].join(' · '), style: const TextStyle(color: Renk.soluk)),
                    const SizedBox(height: 2),
                    const Text('✓ Telefonu doğrulanmış', style: TextStyle(color: Renk.yesil, fontWeight: FontWeight.w800, fontSize: 13)),
                    if (uyelik != null) Text('${ayYil(uyelik!)} tarihinden beri üye', style: const TextStyle(color: Renk.soluk, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _kutu(puanSayisi > 0 ? '★ ${puanYaz(puan)}' : '—', 'Puan'),
              const SizedBox(width: 8),
              _kutu('$satisSayi', 'Satış'),
              const SizedBox(width: 8),
              _kutu('$aktifSayi', 'Aktif ilan'),
              const SizedBox(width: 8),
              _kutu('$puanSayisi', 'Yorum'),
            ],
          ),
          if (puanSayisi > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: kutu(14.0),
              child: Column(
                children: [
                  for (var k = 5; k >= 1; k--)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          SizedBox(width: 26, child: Text('$k ★', style: const TextStyle(color: yildizRenk, fontSize: 13))),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(value: toplam == 0 ? 0 : dagilim[k - 1] / toplam, minHeight: 8, backgroundColor: Renk.cizgi, color: Renk.yesil),
                            ),
                          ),
                          SizedBox(width: 30, child: Text('${dagilim[k - 1]}', textAlign: TextAlign.right, style: const TextStyle(color: Renk.soluk, fontSize: 13))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SaticiScreen extends StatefulWidget {
  const SaticiScreen({super.key, required this.saticiId, this.ad});
  final String saticiId;
  final String? ad;

  @override
  State<SaticiScreen> createState() => _SaticiScreenState();
}

class _SaticiScreenState extends State<SaticiScreen> {
  Map<String, dynamic>? _p;
  List<Ilan> _aktif = [];
  List<Ilan> _satilan = [];
  List<Map<String, dynamic>> _yorumlar = [];
  bool _yuk = true;
  Object? _hata;
  int _sekme = 0;

  bool get _benim => widget.saticiId == uid;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() {
      _yuk = true;
      _hata = null;
    });
    try {
      _p = await saticiProfil(widget.saticiId);
      if (_p == null) throw 'Bu kullanıcı bulunamadı.';
      _aktif = await saticiIlanlari(widget.saticiId, 'aktif');
      _satilan = await saticiIlanlari(widget.saticiId, 'satildi');
      _yorumlar = await yorumlar(widget.saticiId);
    } catch (e) {
      _hata = e;
    }
    if (mounted) setState(() => _yuk = false);
  }

  Future<void> _favori(Ilan i) async {
    if (!await girisGerekli(context)) return;
    final ekle = !app.favoriler.contains(i.id);
    ekle ? app.favoriler.add(i.id) : app.favoriler.remove(i.id);
    setState(() {});
    try {
      await favoriDegistir(i.id, ekle);
    } catch (e) {
      ekle ? app.favoriler.remove(i.id) : app.favoriler.add(i.id);
      if (mounted) {
        setState(() {});
        bildir(context, 'Favori güncellenemedi: $e');
      }
    }
  }

  List<int> get _dagilim {
    final d = List<int>.filled(5, 0);
    for (final y in _yorumlar) {
      d[((y['rating'] as num).toInt() - 1).clamp(0, 4)]++;
    }
    return d;
  }

  Widget _ilanListesi(List<Ilan> l, String bos, {bool satilan = false}) {
    if (l.isEmpty) return Padding(padding: const EdgeInsets.all(32), child: Text(bos, textAlign: TextAlign.center, style: const TextStyle(color: Renk.soluk)));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        children: [
          for (final i in l)
            IlanKarti(
              ilan: i,
              durumGoster: satilan,
              kalp: !satilan && !_benim,
              favori: app.favoriler.contains(i.id),
              onFavori: () => _favori(i),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailScreen(ilan: i))),
            ),
        ],
      ),
    );
  }

  Widget _yorumListesi() {
    if (_yorumlar.isEmpty) return const Padding(padding: EdgeInsets.all(32), child: Text('Bu satıcının henüz yorumu yok.', textAlign: TextAlign.center, style: TextStyle(color: Renk.soluk)));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        children: [
          for (final y in _yorumlar)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: kutu(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(((y['reviewer'] as Map?)?['full_name'] as String?) ?? 'Kullanıcı', style: const TextStyle(fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
                      Text(goreli(DateTime.parse(y['created_at'] as String)), style: const TextStyle(color: Renk.soluk, fontSize: 13)),
                    ],
                  ),
                  Text(yildiz(y['rating'] as num), style: const TextStyle(color: yildizRenk)),
                  if (y['comment'] != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(y['comment'] as String, style: const TextStyle(height: 1.5))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ad ?? 'Satıcı profili'),
        actions: [
          if (!_benim && p != null)
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (!await girisGerekli(context)) return;
                if (!context.mounted) return;
                if (v == 'sikayet') {
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReportScreen(kullaniciId: widget.saticiId)));
                } else {
                  final ok = await onayIste(context, 'Engellemek istiyor musun?', 'Bu kullanıcı sana mesaj gönderemez ve ilanlarını görmezsin.', 'Engelle', tehlike: true);
                  if (!ok) return;
                  try {
                    await engelle(widget.saticiId);
                    if (!context.mounted) return;
                    app.ilanlariYenile();
                    Navigator.of(context).pop();
                    bildir(context, 'Kullanıcı engellendi');
                  } catch (e) {
                    if (context.mounted) bildir(context, 'Engellenemedi: $e');
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'sikayet', child: Text('Şikayet et')),
                PopupMenuItem(value: 'engel', child: Text('Engelle')),
              ],
            ),
        ],
      ),
      body: _yuk
          ? yukleniyor()
          : _hata != null
              ? HataKutusu(_hata!, tekrar: _yukle)
              : RefreshIndicator(
                  onRefresh: _yukle,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SaticiBaslik(
                        ad: (p!['full_name'] as String?) ?? '',
                        rol: {'yetistirici': 'Yetiştirici', 'tuccar': 'Tüccar', 'alici': 'Alıcı'}[p['role']] ?? '',
                        yer: '${p['ilce']}, ${p['il']}',
                        uyelik: p['created_at'] == null ? null : DateTime.parse(p['created_at'] as String),
                        puan: ((p['rating_avg'] as num?) ?? 0).toDouble(),
                        puanSayisi: ((p['rating_count'] as num?) ?? 0).toInt(),
                        aktifSayi: _aktif.length,
                        satisSayi: _satilan.length,
                        dagilim: _dagilim,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              Cip('İlanlar (${_aktif.length})', _sekme == 0, () => setState(() => _sekme = 0)),
                              Cip('Satışlar (${_satilan.length})', _sekme == 1, () => setState(() => _sekme = 1)),
                              Cip('Yorumlar (${_yorumlar.length})', _sekme == 2, () => setState(() => _sekme = 2)),
                            ],
                          ),
                        ),
                      ),
                      if (_sekme == 0) _ilanListesi(_aktif, 'Bu satıcının şu an yayında ilanı yok.'),
                      if (_sekme == 1) _ilanListesi(_satilan, 'Henüz tamamlanmış bir satışı görünmüyor.', satilan: true),
                      if (_sekme == 2) _yorumListesi(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}
