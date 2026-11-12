import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import '../yonetim.dart';
import 'admin_moderasyon.dart';

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

  Future<YoneticiOzet> _getir() => (widget.yukle ?? yonetim.ozet)();

  Future<void> _yenile() async {
    final f = _getir();
    setState(() { _f = f; });
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
          return RefreshIndicator(color: Renk.yesil, onRefresh: _yenile, child: YoneticiGovde(s.data!, yenile: _yenile));
        },
      ),
    );
  }
}

const _rolEtiket = {'yetistirici': 'Yetiştirici', 'tuccar': 'Tüccar', 'alici': 'Alıcı'};
const _platformEtiket = {'web': 'Web', 'ios': 'iPhone', 'android': 'Android', 'diger': 'Diğer'};

class YoneticiGovde extends StatelessWidget {
  const YoneticiGovde(this.o, {super.key, this.yenile});
  final YoneticiOzet o;
  final VoidCallback? yenile;

  @override
  Widget build(BuildContext context) {
    final saat = o.olusturma;
    final platform = o.dagilim('kullanim', 'platform').entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final ornek = o.n('ilanlar', 'ornek_aktif');
    Future<void> git(Widget w) async {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
      yenile?.call();
    }
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
        _ModerasyonBolumu(o, git: git, yenile: yenile),
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
  const _Sayi(this.etiket, this.deger, {this.alt, required this.ikon, this.vurgu = false, this.uyari = false, this.onTap});
  final VoidCallback? onTap;
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
    final kart = Semantics(
      button: onTap != null,
      label: '$etiket: ${sayi(deger)}${alt == null ? '' : ', $alt'}',
      excludeSemantics: true,
      onTap: onTap,
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
              if (onTap != null) Icon(Icons.chevron_right_rounded, size: 20, color: ikinci),
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
    if (onTap == null) return kart;
    return Basma(child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: kart));
  }
}

/// Moderasyon kısayolları + ön onay anahtarı (009_moderasyon.sql).
class _ModerasyonBolumu extends StatelessWidget {
  const _ModerasyonBolumu(this.o, {required this.git, this.yenile});
  final YoneticiOzet o;
  final Future<void> Function(Widget) git;
  final VoidCallback? yenile;

  @override
  Widget build(BuildContext context) {
    final m = o.moderasyon;
    if (m == null) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Text('Moderasyon araçları için Supabase\'de 009_moderasyon.sql çalıştırılmalı.', style: TextStyle(color: Renk.kiremit, fontWeight: FontWeight.w800)),
      );
    }
    int n(String k) => ((m[k] as num?) ?? 0).toInt();
    final onOnay = m['on_onay'] == true;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _Baslik('Moderasyon'),
      _Izgara([
        _Sayi('Bekleyen şikâyet', n('sikayet_yeni'),
            alt: '${sayi(n('sikayet_inceleniyor'))} inceleniyor', ikon: Icons.flag_outlined, uyari: n('sikayet_yeni') > 0, onTap: () => git(const SikayetlerScreen())),
        _Sayi('Onay bekleyen', n('onay_bekleyen'),
            alt: onOnay ? 'ön onay açık' : 'ön onay kapalı',
            ikon: Icons.pending_actions_outlined,
            uyari: n('onay_bekleyen') > 0,
            onTap: () => git(const YoneticiIlanlarScreen(filtre: 'onay', baslikYazi: 'Onay bekleyenler'))),
        _Sayi('Otomatik gizlenen', n('otomatik_gizlenen'),
            alt: '3 şikâyetle kalktı',
            ikon: Icons.visibility_off_outlined,
            uyari: n('otomatik_gizlenen') > 0,
            onTap: () => git(const YoneticiIlanlarScreen(
                filtre: 'otomatik', baslikYazi: 'Otomatik gizlenenler', aciklama: 'Şikâyet haklıysa kaldır, haksızsa yeniden yayına al.'))),
        _Sayi('Şüpheli ilan', n('supheli'),
            alt: 'IBAN, telefon, kapora, ucuz fiyat',
            ikon: Icons.warning_amber_rounded,
            uyari: n('supheli') > 0,
            onTap: () => git(const YoneticiIlanlarScreen(
                filtre: 'supheli', baslikYazi: 'Şüpheli ilanlar', aciklama: 'Açıklamada IBAN, telefon veya kapora geçen ya da piyasanın yarısından ucuz ilanlar. Fotoğraftaki yazılar taranmaz.'))),
      ]),
      Bolum('', [
        Satir('Kullanıcılar', ikon: Icons.manage_accounts_outlined, deger: n('askida_kullanici') > 0 ? '${n('askida_kullanici')} askıda' : null,
            onTap: () => git(const KullanicilarScreen())),
        Satir('Destek mesajları', ikon: Icons.mail_outline_rounded, deger: n('destek_yeni') > 0 ? '${n('destek_yeni')} yeni' : null,
            onTap: () => git(const DestekScreen())),
        Satir('İlanlarda ara', ikon: Icons.search_rounded, onTap: () => git(const YoneticiIlanlarScreen(filtre: 'tumu', baslikYazi: 'İlanlarda ara'))),
        Satir('Gizlenen ve kaldırılan ilanlar', ikon: Icons.inventory_2_outlined,
            onTap: () => git(const YoneticiIlanlarScreen(filtre: 'gizli', baslikYazi: 'Gizlenen ve kaldırılanlar'))),
        _OnOnay(onOnay, yenile: yenile),
      ]),
    ]);
  }
}

class _OnOnay extends StatefulWidget {
  const _OnOnay(this.acik, {this.yenile});
  final bool acik;
  final VoidCallback? yenile;
  @override
  State<_OnOnay> createState() => _OnOnayState();
}

class _OnOnayState extends State<_OnOnay> {
  late bool _acik = widget.acik;
  bool _mesgul = false;

  Future<void> _degistir(bool v) async {
    if (_mesgul) return;
    if (v) {
      final ok = await onayIste(context, 'Ön onay açılsın mı?',
          'Bundan sonra verilen her ilan, sen onaylayana kadar yayına çıkmaz. Satıcıya "onay bekliyor" yazar.', 'Ön onayı aç');
      if (!ok || !mounted) return;
    }
    setState(() {
      _acik = v;
      _mesgul = true;
    });
    try {
      await yonetim.ayar('on_onay', v);
      if (mounted) bildir(context, v ? 'Ön onay açık: yeni ilanlar onayını bekleyecek' : 'Ön onay kapalı: ilanlar hemen yayına çıkar');
      widget.yenile?.call();
    } catch (e) {
      if (mounted) {
        setState(() => _acik = !v);
        bildir(context, 'Ayar değiştirilemedi: $e');
      }
    } finally {
      if (mounted) setState(() => _mesgul = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      AnahtarSatir('Ön onay modu', _acik, _degistir, alt: 'Yeni ilanlar yönetici onayından sonra yayına çıkar');
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
