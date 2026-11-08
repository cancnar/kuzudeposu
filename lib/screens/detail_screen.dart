import 'package:flutter/material.dart';

import '../data.dart';
import '../galeri.dart';
import '../rehber.dart';
import '../video.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'chat_screen.dart';
import 'satici_screen.dart';
import 'phone_screen.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key, this.ilan, this.ilanId});
  final Ilan? ilan;
  final String? ilanId;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  Ilan? _i;
  List<Map<String, dynamic>> _yorumlar = [];
  bool _yuk = true;
  Object? _hata;
  FiyatOzeti? _piyasa;
  Map<String, dynamic>? _stat;
  SaticiGuven? _guven;

  @override
  void initState() {
    super.initState();
    _i = widget.ilan;
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() {
      _yuk = true;
      _hata = null;
    });
    try {
      if (_i == null) {
        _i = await ilanGetir(widget.ilanId!);
        if (_i == null) throw 'İlan bulunamadı veya yayından kaldırıldı.';
      } else if (_i!.foto.isEmpty) {
        await fotolariDoldur([_i!]);
      }
      _yorumlar = await yorumlar(_i!.saticiId);
      try {
        final pr = await saticiProfil(_i!.saticiId);
        final sat = await saticiSatisSayisi(_i!.saticiId);
        _guven = SaticiGuven(pr?['created_at'] == null ? null : DateTime.parse(pr!['created_at'] as String), sat);
      } catch (_) {}
      if (_i!.aktif) {
        if (_benim) {
          _stat = await ilanIstatistik(_i!.id).catchError((_) => null);
        } else {
          ilanGoruntule(_i!.id);
        }
        _piyasa = await fiyatOzeti(_i!).catchError((_) => null);
      }
    } catch (e) {
      _hata = e;
    }
    if (mounted) setState(() => _yuk = false);
  }

  bool get _benim => _i != null && _i!.saticiId == uid;

  Future<void> _favori() async {
    final i = _i!;
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

  Future<void> _mesaj() async {
    if (!await girisGerekli(context)) return;
    try {
      final id = await konusmaAc(_i!);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(konusmaId: id)));
    } catch (e) {
      if (mounted) bildir(context, 'Konuşma açılamadı: $e');
    }
  }

  Future<void> _teklif() async {
    if (!await girisGerekli(context)) return;
    final c = TextEditingController();
    final tutar = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Teklif ver'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('İstenen fiyat: ${tl(_i!.toplam)}', style: const TextStyle(color: Renk.soluk)),
            const SizedBox(height: 10),
            TextField(controller: c, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Teklifin (₺)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Teklifi gönder')),
        ],
      ),
    );
    final t = sayiOku(tutar ?? '');
    if (t == null || t <= 0) return;
    try {
      final id = await konusmaAc(_i!);
      await mesajGonder(id, 'Merhaba, bu ilan için ${tl(t)} teklif ediyorum. Uygun olur mu?');
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(konusmaId: id)));
    } catch (e) {
      if (mounted) bildir(context, 'Teklif gönderilemedi: $e');
    }
  }

  Widget _piyasaKutusu(Ilan i) {
    final p = _piyasa;
    if (p == null) return const SizedBox.shrink();
    final fark = (i.kgFiyat - p.medyan) / p.medyan * 100;
    final String ozet;
    final Color renk;
    if (fark <= -8) {
      ozet = 'Piyasanın %${fark.abs().round()} altında';
      renk = Renk.okYazi;
    } else if (fark >= 8) {
      ozet = 'Piyasanın %${fark.round()} üstünde';
      renk = Renk.kiremit;
    } else {
      ozet = 'Piyasa fiyatına yakın';
      renk = Renk.okYazi;
    }
    // Ölçek: benzer ilanların en düşüğü ile en yükseği, iki yanda biraz pay.
    final lo = [p.enDusuk, i.kgFiyat].reduce((a, b) => a < b ? a : b).toDouble();
    final hi = [p.enYuksek, i.kgFiyat].reduce((a, b) => a > b ? a : b).toDouble();
    final pay = ((hi - lo) * 0.12).clamp(1.0, double.infinity).toDouble();
    final min = lo - pay, max = hi + pay;
    double konum(num v) => ((v - min) / (max - min)).clamp(0.0, 1.0).toDouble();
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: kutu(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text(ozet, style: TextStyle(fontWeight: FontWeight.w800, color: renk, fontSize: 15))),
              Text('${p.adet} benzer ilan', style: const TextStyle(color: Renk.soluk, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            label: 'Benzer ilanlar ${sayi(p.enDusuk)} ile ${sayi(p.enYuksek)} lira kilogram arasında, ortanca ${sayi(p.medyan)}. Bu ilan ${sayi(i.kgFiyat)}.',
            child: SizedBox(
              height: 26,
              child: LayoutBuilder(
                builder: (context, k) {
                  final w = k.maxWidth;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(left: 0, right: 0, top: 10, child: Container(height: 6, decoration: BoxDecoration(color: Renk.zemin2, borderRadius: BorderRadius.circular(3)))),
                      Positioned(
                        left: w * konum(p.enDusuk),
                        width: (w * (konum(p.enYuksek) - konum(p.enDusuk))).clamp(6.0, w).toDouble(),
                        top: 10,
                        child: Container(height: 6, decoration: BoxDecoration(color: const Color(0xFFC9D8BE), borderRadius: BorderRadius.circular(3))),
                      ),
                      Positioned(left: w * konum(p.medyan) - 1, top: 4, child: Container(width: 2, height: 18, color: Renk.soluk)),
                      Positioned(
                        left: w * konum(i.kgFiyat) - 11,
                        top: 2,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(color: renk, shape: BoxShape.circle, border: Border.all(color: Renk.kart, width: 3)),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          DefaultTextStyle.merge(
            style: const TextStyle(color: Renk.soluk, fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [Text('${sayi(lo)} ₺/kg'), Text('Ortanca ${sayi(p.medyan)}'), Text('${sayi(hi)} ₺/kg')],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Benzer ilanlar ${sayi(p.enDusuk)}–${sayi(p.enYuksek)} ₺/kg, bu ilan ${sayi(i.kgFiyat)} ₺/kg.',
            style: const TextStyle(color: Renk.soluk, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _istatistik() {
    final st = _stat;
    if (st == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      decoration: kutu(18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final e in [
            ['Görüntülenme', '${st['goruntulenme']}'],
            ['Favori', '${st['favori']}'],
            ['Konuşma', '${st['konusma']}'],
          ])
            Column(children: [Text(e[1], style: baslik(22)), Text(e[0], style: const TextStyle(color: Renk.soluk, fontSize: 12))]),
        ],
      ),
    );
  }

  Widget _guvenUyarisi() => Container(
        margin: const EdgeInsets.only(top: 14),
        padding: const EdgeInsets.all(14),
        width: double.infinity,
        decoration: BoxDecoration(color: Renk.zemin2, borderRadius: BorderRadius.circular(16)),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_outlined, size: 20, color: Renk.murekkep),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Hayvanı yerinde görmeden kapora veya ön ödeme gönderme. Parayı hayvanı teslim alırken öde. Şüpheli ilanı bildir.',
                style: TextStyle(fontSize: 13, height: 1.45),
              ),
            ),
          ],
        ),
      );

  Future<void> _uzat() async {
    try {
      await ilanUzat(_i!);
      app.ilanlariYenile();
      if (!mounted) return;
      bildir(context, 'İlan süresi 30 gün uzatıldı');
      _i = null;
      _yukle();
    } catch (e) {
      if (mounted) bildir(context, 'Süre uzatılamadı: $e');
    }
  }

  Widget _sureKutusu(Ilan i) {
    final k = i.kalanGun;
    if (k == null) return const SizedBox.shrink();
    final az = k <= 7;
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      width: double.infinity,
      decoration: BoxDecoration(color: az ? const Color(0xFFF6E1D9) : Renk.zemin2, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(child: Text(k <= 0 ? 'İlanın süresi doluyor' : 'İlan $k gün sonra yayından kalkar', style: TextStyle(fontWeight: FontWeight.w700, color: az ? Renk.kiremit : Renk.murekkep))),
          TextButton(onPressed: _uzat, child: const Text('30 gün uzat')),
        ],
      ),
    );
  }

  Future<void> _durum(String d, String mesaj) async {
    try {
      await ilanDurumu(_i!.id, d);
      app.ilanlariYenile();
      if (!mounted) return;
      bildir(context, mesaj);
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) bildir(context, 'İşlem yapılamadı: $e');
    }
  }

  Widget _bilgi(String ad, String deger) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Renk.ayrac))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ad, style: const TextStyle(color: Renk.soluk, fontSize: 12)),
            const SizedBox(height: 2),
            Text(deger, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ],
        ),
      );

  Widget _bilgiler(Ilan i) {
    final l = [
      _bilgi('Tür', i.turAd),
      _bilgi('Cinsiyet', i.cinsiyetAd),
      _bilgi(i.suru ? 'Yaş aralığı' : 'Yaş', i.yasMetni),
      _bilgi(i.suru ? 'Ortalama ağırlık' : 'Canlı ağırlık', '${sayi(i.agirlik)} kg'),
      _bilgi('Adet', '${i.adet} baş'),
      _bilgi('Kg fiyatı', '${sayi(i.kgFiyat)} ₺'),
      if (i.amacAd != null) _bilgi('Satış amacı', i.amacAd!),
      _bilgi('Teslimat', i.teslimatAd),
      if (i.suru) _bilgi('Satış şekli', i.satisSekli == 'adet_adet' ? 'Adet adet de satılır' : 'Toplu satılır'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text('Bilgiler', style: baslik(20)),
        for (var k = 0; k < l.length; k += 2)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: l[k]),
              const SizedBox(width: 20),
              Expanded(child: k + 1 < l.length ? l[k + 1] : const SizedBox.shrink()),
            ],
          ),
      ],
    );
  }

  Widget _puanOzeti(Ilan i) {
    final sayilar = List<int>.filled(5, 0);
    for (final y in _yorumlar) {
      final p = ((y['rating'] as num).toInt() - 1).clamp(0, 4);
      sayilar[p]++;
    }
    final toplam = _yorumlar.isEmpty ? 1 : _yorumlar.length;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: kutu(18),
      child: Row(
        children: [
          Column(
            children: [
              Text(puanYaz(i.saticiPuan), style: baslik(34)),
              Text(yildiz(i.saticiPuan), style: const TextStyle(color: yildizRenk)),
              Text('${i.saticiPuanSayisi} değerlendirme', style: const TextStyle(color: Renk.soluk, fontSize: 12)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              children: [
                for (var k = 5; k >= 1; k--)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        SizedBox(width: 14, child: Text('$k', style: const TextStyle(color: Renk.soluk))),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: sayilar[k - 1] / toplam,
                              minHeight: 8,
                              backgroundColor: Renk.zemin2,
                              color: Renk.yesil,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i = _i;
    if (i == null) {
      return Scaffold(appBar: AppBar(), body: _hata != null ? HataKutusu(_hata!, tekrar: _yukle) : yukleniyor());
    }
    final fotolar = i.foto;
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Stack(
                  children: [
                    FotoGaleri(fotolar: fotolar),
                    Positioned(
                      left: 12,
                      top: MediaQuery.of(context).padding.top + 10,
                      child: YuzenDugme(ikon: Icons.arrow_back_ios_new_rounded, ipucu: 'Geri', renk: Renk.murekkep, onPressed: () => Navigator.of(context).pop()),
                    ),
                    if (!_benim)
                      Positioned(
                        right: 12,
                        top: MediaQuery.of(context).padding.top + 10,
                        child: YuzenDugme(
                          ikon: app.favoriler.contains(i.id) ? Icons.favorite : Icons.favorite_border,
                          ipucu: app.favoriler.contains(i.id) ? 'Favorilerden çıkar' : 'Favorilere ekle',
                          renk: Renk.kiremit,
                          titresim: true,
                          onPressed: _favori,
                        ),
                      ),
                    if (i.videoVar)
                      Positioned(
                        left: 12,
                        bottom: 12,
                        child: Semantics(
                          button: true,
                          label: 'Hayvanın videosunu izle',
                          excludeSemantics: true,
                          child: Basma(
                            child: Material(
                              color: const Color(0xA81C180F),
                              shape: const StadiumBorder(),
                              child: InkWell(
                                customBorder: const StadiumBorder(),
                                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VideoEkrani(url: videoUrl(i.videoYol!)))),
                                child: const Padding(
                                  padding: EdgeInsets.fromLTRB(10, 9, 14, 9),
                                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                                    Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                                    SizedBox(width: 4),
                                    Text('Videoyu izle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                                  ]),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!i.aktif)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Renk.murekkep, borderRadius: BorderRadius.circular(8)),
                          child: Text(i.durum == 'satildi' ? 'Bu hayvan satıldı' : 'Bu ilan yayında değil', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        ),
                      Row(
                        children: [
                          const Icon(Icons.place_outlined, size: 16, color: Renk.soluk),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text('${i.yer} · ${goreli(i.olusturma)}', style: const TextStyle(color: Renk.soluk, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(i.suru ? '${i.cins} · ${i.adet} baş' : i.cins, style: baslik(28)),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.end,
                        spacing: 10,
                        children: [
                          Text(tl(i.toplam), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 26, color: Renk.murekkep, fontFeatures: [FontFeature.tabularFigures()])),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('${sayi(i.kgFiyat)} ₺/kg${i.pazarlik ? ' · pazarlığa açık' : ''}', style: const TextStyle(color: Renk.soluk, fontSize: 14)),
                          ),
                        ],
                      ),
                      if (i.belgeler.isNotEmpty || i.amacAd != null) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final b in i.belgeler)
                              b == 'kupe' ? const Rozet('Küpeli', tur: RozetTuru.kupe) : Rozet(belgeEtiket[b] ?? b, tur: RozetTuru.ok),
                            if (i.amacAd != null) Rozet(i.amacAd!),
                          ],
                        ),
                      ],
                      if (i.aktif && !_benim) _piyasaKutusu(i),
                      if (_benim && i.aktif) _istatistik(),
                      if (_benim && i.aktif) _sureKutusu(i),
                      _bilgiler(i),
                      if (i.aciklama != null && i.aciklama!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(i.aciklama!, style: const TextStyle(height: 1.5)),
                      ],
                      if (!_benim && i.aktif) AliciRehberi(ilan: i, aliciIl: app.profil?['il'] as String?),
                      if (!_benim && i.aktif) _guvenUyarisi(),
                      const SizedBox(height: 22),
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SaticiScreen(saticiId: i.saticiId, ad: i.saticiAd))),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: Renk.okZemin,
                                child: Text(i.saticiAd.isEmpty ? '?' : i.saticiAd.substring(0, 1).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, color: Renk.yesil)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_benim ? 'Siz' : i.saticiAd, style: const TextStyle(fontWeight: FontWeight.w800)),
                                    const Row(mainAxisSize: MainAxisSize.min, children: [
                                      Icon(Icons.verified_outlined, size: 15, color: Renk.okYazi),
                                      SizedBox(width: 4),
                                      Flexible(child: Text('Telefonu doğrulanmış', style: TextStyle(color: Renk.okYazi, fontSize: 13, fontWeight: FontWeight.w700))),
                                    ]),
                                    if (_guven != null)
                                      Text(
                                        _guven!.yeni
                                            ? 'Yeni üye · henüz satışı yok, dikkatli ol'
                                            : '${_guven!.satis} satış${_guven!.uyelik == null ? '' : ' · üye: ${ayYil(_guven!.uyelik!)}'}',
                                        style: TextStyle(color: _guven!.yeni ? Renk.kiremit : Renk.soluk, fontSize: 12.5, fontWeight: _guven!.yeni ? FontWeight.w700 : FontWeight.w400),
                                      ),
                                  ],
                                ),
                              ),
                              const Text('Profil', style: TextStyle(color: Renk.yesil, fontWeight: FontWeight.w800, fontSize: 14)),
                              const Icon(Icons.chevron_right, color: Renk.yesil),
                            ],
                          ),
                        ),
                      ),
                      if (i.saticiPuanSayisi > 0) _puanOzeti(i),
                      const SizedBox(height: 18),
                      Text('Satıcı yorumları', style: baslik(19)),
                      if (_yuk)
                        yukleniyor()
                      else if (_yorumlar.isEmpty)
                        const Padding(padding: EdgeInsets.only(top: 8), child: Text('Bu satıcının henüz yorumu yok.', style: TextStyle(color: Renk.soluk)))
                      else
                        for (final y in _yorumlar)
                          Container(
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.all(14),
                            width: double.infinity,
                            decoration: kutu(16, Golge.hafif),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(((y['reviewer'] as Map?)?['full_name'] as String?) ?? 'Kullanıcı', style: const TextStyle(fontWeight: FontWeight.w800)),
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
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(color: Renk.kart.withValues(alpha: 0.97), border: const Border(top: BorderSide(color: Renk.ayrac))),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: SafeArea(
              top: false,
              child: _benim
                  ? Row(
                      children: [
                        if (i.aktif) ...[
                          Expanded(child: OutlinedButton(onPressed: () => _durum('pasif', 'İlan yayından kaldırıldı'), child: const Text('Yayından kaldır'))),
                          const SizedBox(width: 10),
                          Expanded(child: FilledButton(onPressed: () => _durum('satildi', 'İlan satıldı olarak işaretlendi'), child: const Text('Satıldı'))),
                        ] else
                          Expanded(child: FilledButton(onPressed: () => _durum('aktif', 'İlan yeniden yayında'), child: const Text('Yeniden yayınla'))),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Basma(
                            child: OutlinedButton.icon(
                              onPressed: i.aktif ? _mesaj : null,
                              icon: const Icon(Icons.chat_bubble_outline, size: 20),
                              label: const Text('Mesaj gönder'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Basma(
                            child: FilledButton(
                              onPressed: i.aktif ? _teklif : null,
                              child: const Text('Teklif ver'),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
