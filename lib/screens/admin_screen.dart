import 'package:flutter/material.dart';

import '../data.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets.dart';

/// Yönetici paneli: kullanım, üye, ilan ve etkileşim sayıları.
/// Sadece `admins` tablosundaki hesaplar görür (008_yonetici.sql); diğerleri için RPC hata verir.
class YoneticiScreen extends StatefulWidget {
  const YoneticiScreen({super.key, this.yukle});

  /// Testlerde sahte veri vermek için.
  final Future<YoneticiOzet> Function()? yukle;

  @override
  State<YoneticiScreen> createState() => _YoneticiScreenState();
}

class _YoneticiScreenState extends State<YoneticiScreen> {
  late Future<YoneticiOzet> _f = _getir();

  Future<YoneticiOzet> _getir() => (widget.yukle ?? yoneticiOzet)();

  Future<void> _yenile() async {
    final f = _getir();
    setState(() => _f = f);
    await f.catchError((_) => YoneticiOzet(const {}));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yönetici paneli'),
        actions: [IconButton(tooltip: 'Yenile', icon: const Icon(Icons.refresh_rounded), onPressed: _yenile)],
      ),
      body: FutureBuilder<YoneticiOzet>(
        future: _f,
        builder: (context, s) {
          if (s.connectionState != ConnectionState.done) return yukleniyor();
          if (s.hasError) {
            final yetki = '${s.error}'.contains('yetki');
            return HataKutusu(yetki ? 'Bu sayfa sadece yöneticilere açık.' : '${s.error}\n(008_yonetici.sql çalıştırıldı mı?)', tekrar: _yenile);
          }
          return RefreshIndicator(color: Renk.yesil, onRefresh: _yenile, child: YoneticiGovde(s.data!));
        },
      ),
    );
  }
}

/// Örnek veri: widget testleri ve yerel önizleme (localhost/?onizleme=yonetici) için. Gerçek veri değildir.
final onizlemeOzeti = <String, dynamic>{
  'kullanim': {'toplam_cihaz': 1250, 'bugun': 140, 'son7': 610, 'son30': 1100, 'misafir_bugun': 52, 'platform': {'web': 700, 'ios': 250, 'android': 150}},
  'uyeler': {'toplam': 412, 'bugun': 9, 'son7': 61, 'son30': 230, 'kayitli_ama_profilsiz': 14, 'rol': {'yetistirici': 210, 'tuccar': 48, 'alici': 154}},
  'ilanlar': {
    'aktif': 87, 'toplam': 140, 'bugun': 4, 'son7': 31, 'satildi': 29, 'pasif': 6, 'suresi_doldu': 18, 'videolu': 12, 'goruntulenme': 15873,
    'ilan_veren': 73, 'ornek_aktif': 17, 'tur': {'kucukbas': 60, 'buyukbas': 22, 'at': 3, 'kanatli': 2},
    'il': [{'il': 'Manisa', 'n': 41}, {'il': 'Afyonkarahisar', 'n': 12}, {'il': 'İzmir', 'n': 9}],
  },
  'etkilesim': {'aktif_talep': 23, 'sohbet': 310, 'mesaj': 2480, 'mesaj_son7': 640, 'favori': 905, 'degerlendirme': 44, 'bekleyen_sikayet': 3},
  'gunluk': [for (var i = 0; i < 14; i++) {'gun': '2026-11-${(i + 1).toString().padLeft(2, '0')}', 'cihaz': 40 + i * 7 + (i == 13 ? 9 : 0), 'uye': i % 4, 'ilan': i % 3}],
  'olusturma': '2026-11-12T20:15:00+03:00',
};

const _rolEtiket = {'yetistirici': 'Yetiştirici', 'tuccar': 'Tüccar', 'alici': 'Alıcı'};
const _platformEtiket = {'web': 'Web', 'ios': 'iPhone', 'android': 'Android', 'diger': 'Diğer'};

class YoneticiGovde extends StatelessWidget {
  const YoneticiGovde(this.o, {super.key});
  final YoneticiOzet o;

  @override
  Widget build(BuildContext context) {
    final saat = o.olusturma;
    final platform = o.dagilim('kullanim', 'platform').entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final sikayet = o.n('etkilesim', 'bekleyen_sikayet');
    final ornek = o.n('ilanlar', 'ornek_aktif');
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
          child: Text(
            '${saat == null ? '' : 'Son güncelleme ${_ik(saat.hour)}:${_ik(saat.minute)} · '}Örnek hesaplar sayılmaz',
            style: const TextStyle(color: Renk.soluk, fontSize: 13),
          ),
        ),
        if (sikayet > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFF7E3DC), borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                const Icon(Icons.flag_outlined, color: Renk.kiremit),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('$sikayet şikâyet inceleme bekliyor',
                      style: const TextStyle(color: Renk.kiremit, fontWeight: FontWeight.w800)),
                ),
              ]),
            ),
          ),
        const _Baslik('Kullanım'),
        _Izgara([
          _Sayi('Uygulamayı kullanan', o.n('kullanim', 'toplam_cihaz'), alt: 'cihaz · misafirler dahil', ikon: Icons.phone_iphone_rounded, vurgu: true),
          _Sayi('Bugün', o.n('kullanim', 'bugun'), alt: '${sayi(o.n('kullanim', 'misafir_bugun'))} misafir', ikon: Icons.today_outlined),
          _Sayi('Son 7 gün', o.n('kullanim', 'son7'), alt: 'farklı cihaz', ikon: Icons.date_range_outlined),
          _Sayi('Son 30 gün', o.n('kullanim', 'son30'),
              alt: platform.isEmpty ? 'farklı cihaz' : platform.map((e) => '${_platformEtiket[e.key] ?? e.key} ${sayi(e.value)}').join(' · '),
              ikon: Icons.calendar_month_outlined),
        ]),
        Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: GunlukGrafik(o)),
        const _Baslik('Üyeler'),
        _Izgara([
          _Sayi('Toplam üye', o.n('uyeler', 'toplam'), alt: '+${sayi(o.n('uyeler', 'bugun'))} bugün', ikon: Icons.people_alt_outlined, vurgu: true),
          _Sayi('Son 7 gün', o.n('uyeler', 'son7'), alt: 'yeni üye', ikon: Icons.person_add_alt_1_outlined),
          _Sayi('Son 30 gün', o.n('uyeler', 'son30'), alt: 'yeni üye', ikon: Icons.group_add_outlined),
          _Sayi('Profilini bitirmeyen', o.n('uyeler', 'kayitli_ama_profilsiz'), alt: 'kodu girdi, profil yok', ikon: Icons.hourglass_empty_rounded),
        ]),
        _Kart('Üye tipi', _OranListesi({for (final e in o.dagilim('uyeler', 'rol').entries) _rolEtiket[e.key] ?? e.key: e.value})),
        const _Baslik('İlanlar'),
        _Izgara([
          _Sayi('Aktif ilan', o.n('ilanlar', 'aktif'), alt: '+${sayi(o.n('ilanlar', 'bugun'))} bugün', ikon: Icons.storefront_outlined, vurgu: true),
          _Sayi('Toplam ilan', o.n('ilanlar', 'toplam'), alt: '${sayi(o.n('ilanlar', 'ilan_veren'))} kişi ilan verdi', ikon: Icons.inventory_2_outlined),
          _Sayi('Satıldı', o.n('ilanlar', 'satildi'), ikon: Icons.handshake_outlined),
          _Sayi('Yayında değil', o.n('ilanlar', 'pasif'), alt: 'pasif veya gizlenmiş', ikon: Icons.visibility_off_outlined),
          _Sayi('Süresi dolan', o.n('ilanlar', 'suresi_doldu'), alt: 'uzatılmamış', ikon: Icons.timer_off_outlined),
          _Sayi('Görüntülenme', o.n('ilanlar', 'goruntulenme'), alt: '${sayi(o.n('ilanlar', 'videolu'))} aktif ilanda video', ikon: Icons.visibility_outlined),
        ]),
        _Kart('Türlere göre aktif ilan', _OranListesi({for (final e in o.dagilim('ilanlar', 'tur').entries) turEtiket[e.key] ?? e.key: e.value})),
        _Kart('En çok ilan olan iller', _OranListesi({for (final e in o.iller) e.il: e.n})),
        if (ornek > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text('Ayrıca ${sayi(ornek)} örnek ilan yayında (sayılara dahil değil).', style: const TextStyle(color: Renk.soluk, fontSize: 13)),
          ),
        const _Baslik('Etkileşim'),
        _Izgara([
          _Sayi('Alıcı talebi', o.n('etkilesim', 'aktif_talep'), alt: 'aktif', ikon: Icons.search_rounded),
          _Sayi('Sohbet', o.n('etkilesim', 'sohbet'), ikon: Icons.forum_outlined),
          _Sayi('Mesaj', o.n('etkilesim', 'mesaj'), alt: '${sayi(o.n('etkilesim', 'mesaj_son7'))} son 7 günde', ikon: Icons.chat_bubble_outline_rounded),
          _Sayi('Favori', o.n('etkilesim', 'favori'), ikon: Icons.favorite_border_rounded),
          _Sayi('Değerlendirme', o.n('etkilesim', 'degerlendirme'), ikon: Icons.star_border_rounded),
          _Sayi('Bekleyen şikâyet', sikayet, ikon: Icons.flag_outlined, uyari: sikayet > 0),
        ]),
      ],
    );
  }
}

String _ik(int x) => x.toString().padLeft(2, '0');

class _Baslik extends StatelessWidget {
  const _Baslik(this.yazi);
  final String yazi;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 10),
        child: Semantics(header: true, child: Text(yazi, style: baslik(20))),
      );
}

/// Dar ekranda 2, geniş ekranda 3 sütun.
class _Izgara extends StatelessWidget {
  const _Izgara(this.cocuklar);
  final List<Widget> cocuklar;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: LayoutBuilder(builder: (context, k) {
          final sutun = k.maxWidth >= 520 ? 3 : 2;
          const ara = 10.0;
          final g = (k.maxWidth - ara * (sutun - 1)) / sutun;
          return Wrap(
            spacing: ara,
            runSpacing: ara,
            children: [for (final c in cocuklar) SizedBox(width: g, child: c)],
          );
        }),
      );
}

class _Sayi extends StatelessWidget {
  const _Sayi(this.etiket, this.deger, {this.alt, required this.ikon, this.vurgu = false, this.uyari = false});
  final String etiket;
  final int deger;
  final String? alt;
  final IconData ikon;
  final bool vurgu;
  final bool uyari;

  @override
  Widget build(BuildContext context) {
    final renk = uyari ? Renk.kiremit : (vurgu ? Renk.krem : Renk.murekkep);
    final ikinci = vurgu ? Renk.krem.withValues(alpha: .8) : Renk.soluk;
    return Semantics(
      label: '$etiket: ${sayi(deger)}${alt == null ? '' : ', $alt'}',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: 108),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: vurgu
            ? BoxDecoration(color: Renk.yesil, borderRadius: BorderRadius.circular(18), boxShadow: Golge.kart)
            : kutu(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(ikon, size: 18, color: vurgu ? Renk.krem : (uyari ? Renk.kiremit : Renk.yesil)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(etiket, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: ikinci, fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            ]),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(sayi(deger), style: baslik(30, renk: renk)),
            ),
            if (alt != null) Text(alt!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: ikinci, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _Kart extends StatelessWidget {
  const _Kart(this.baslikYazi, this.icerik);
  final String baslikYazi;
  final Widget icerik;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: kutu(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(baslikYazi, style: const TextStyle(color: Renk.soluk, fontWeight: FontWeight.w800, fontSize: 13)),
            const SizedBox(height: 10),
            icerik,
          ]),
        ),
      );
}

/// Etiket + yatay oran çubuğu + sayı. Büyükten küçüğe sıralı.
class _OranListesi extends StatelessWidget {
  const _OranListesi(this.veri);
  final Map<String, int> veri;
  @override
  Widget build(BuildContext context) {
    if (veri.isEmpty) return const Text('Henüz veri yok', style: TextStyle(color: Renk.soluk));
    final l = veri.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final enBuyuk = l.first.value == 0 ? 1 : l.first.value;
    final toplam = l.fold<int>(0, (t, e) => t + e.value);
    return Column(children: [
      for (final e in l)
        Semantics(
          label: '${e.key}: ${sayi(e.value)}',
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              SizedBox(width: 96, child: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: Container(
                    height: 10,
                    color: Renk.zemin2,
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(widthFactor: e.value / enBuyuk, heightFactor: 1, child: Container(color: Renk.yesil)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 76,
                child: Text(
                  '${sayi(e.value)}${toplam > 0 ? ' · %${(e.value * 100 / toplam).round()}' : ''}',
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ),
            ]),
          ),
        ),
    ]);
  }
}

/// Son 14 günün sütun grafiği: kullanan cihaz / yeni üye / yeni ilan.
class GunlukGrafik extends StatefulWidget {
  const GunlukGrafik(this.o, {super.key});
  final YoneticiOzet o;
  @override
  State<GunlukGrafik> createState() => _GunlukGrafikState();
}

class _GunlukGrafikState extends State<GunlukGrafik> {
  int _secim = 0;
  static const _adlar = ['Kullanan cihaz', 'Yeni üye', 'Yeni ilan'];
  static const _aylar = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];

  @override
  Widget build(BuildContext context) {
    final g = widget.o.gunluk;
    final d = <int>[for (final x in g) (switch (_secim) { 1 => x.uye, 2 => x.ilan, _ => x.cihaz })];
    final enBuyuk = d.isEmpty ? 0 : d.reduce((a, b) => a > b ? a : b);
    final toplam = d.fold<int>(0, (t, x) => t + x);
    String tarih(DateTime t) => '${t.day} ${_aylar[t.month - 1]}';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: kutu(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Son 14 gün', style: TextStyle(color: Renk.soluk, fontWeight: FontWeight.w800, fontSize: 13))),
          Text('toplam ${sayi(toplam)}', style: const TextStyle(color: Renk.soluk, fontSize: 13)),
        ]),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [for (var i = 0; i < _adlar.length; i++) Cip(_adlar[i], _secim == i, () => setState(() => _secim = i))]),
        ),
        const SizedBox(height: 12),
        Semantics(
          label: '${_adlar[_secim]}, son 14 gün: toplam ${sayi(toplam)}, bugün ${d.isEmpty ? 0 : sayi(d.last)}',
          excludeSemantics: true,
          child: SizedBox(
            height: 120,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var i = 0; i < d.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      if (d[i] > 0 && (d[i] == enBuyuk || i == d.length - 1))
                        FittedBox(child: Text(sayi(d[i]), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Renk.soluk))),
                      Container(
                        height: enBuyuk == 0 ? 3.0 : 3.0 + 92 * d[i] / enBuyuk,
                        decoration: BoxDecoration(
                          color: i == d.length - 1 ? Renk.yesil : Renk.yesil.withValues(alpha: .45),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ]),
                  ),
                ),
            ]),
          ),
        ),
        if (g.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(children: [
            Text(tarih(g.first.gun), style: const TextStyle(color: Renk.soluk, fontSize: 12)),
            const Spacer(),
            const Text('Bugün', style: TextStyle(color: Renk.soluk, fontSize: 12, fontWeight: FontWeight.w800)),
          ]),
        ],
      ]),
    );
  }
}
