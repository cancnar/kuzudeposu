import 'package:flutter/material.dart';

import '../data.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'chat_screen.dart';
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
  int _foto = 0;

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

  Widget _kutu(String ad, String deger) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Renk.cizgi)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ad, style: const TextStyle(color: Renk.soluk, fontSize: 13)),
            const SizedBox(height: 2),
            Text(deger, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      );

  Widget _puanOzeti(Ilan i) {
    final sayilar = List<int>.filled(5, 0);
    for (final y in _yorumlar) {
      final p = ((y['rating'] as num).toInt() - 1).clamp(0, 4);
      sayilar[p]++;
    }
    final toplam = _yorumlar.isEmpty ? 1 : _yorumlar.length;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Renk.cizgi)),
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
                              backgroundColor: Renk.cizgi,
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
                    SizedBox(
                      height: 260,
                      child: fotolar.isEmpty
                          ? const FotoKutusu(yukseklik: 260)
                          : PageView(
                              onPageChanged: (p) => setState(() => _foto = p),
                              children: [for (final f in fotolar) FotoKutusu(url: f, yukseklik: 260)],
                            ),
                    ),
                    Positioned(
                      left: 8,
                      top: MediaQuery.of(context).padding.top + 8,
                      child: CircleAvatar(
                        backgroundColor: Colors.white,
                        child: IconButton(icon: const Icon(Icons.arrow_back, color: Renk.yesil), onPressed: () => Navigator.of(context).pop()),
                      ),
                    ),
                    if (!_benim)
                      Positioned(
                        right: 8,
                        top: MediaQuery.of(context).padding.top + 8,
                        child: CircleAvatar(
                          backgroundColor: Colors.white,
                          child: IconButton(
                            onPressed: _favori,
                            icon: Icon(app.favoriler.contains(i.id) ? Icons.favorite : Icons.favorite_border, color: Renk.kiremit),
                          ),
                        ),
                      ),
                    if (fotolar.length > 1)
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                          child: Text('${_foto + 1}/${fotolar.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Text(i.cins, style: baslik(25))),
                          const SizedBox(width: 8),
                          Text(tl(i.toplam), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: Renk.kiremit)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('${i.suru ? '${i.adet} baş · ' : ''}${i.yer}', style: const TextStyle(color: Renk.soluk)),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 2.6,
                        children: [
                          _kutu('Tür', i.turAd),
                          _kutu('Cins', i.cins),
                          _kutu('Cinsiyet', i.cinsiyetAd),
                          _kutu('Adet', '${i.adet} baş'),
                          _kutu(i.suru ? 'Yaş aralığı' : 'Yaş', i.yasMetni),
                          _kutu(i.suru ? 'Ortalama ağırlık' : 'Canlı ağırlık', '${sayi(i.agirlik)} kg'),
                          _kutu('Kg fiyatı', '${sayi(i.kgFiyat)} ₺'),
                          if (i.suru) _kutu('Satış şekli', i.satisSekli == 'adet_adet' ? 'Adet adet de satılır' : 'Toplu satılır'),
                        ],
                      ),
                      if (i.aciklama != null && i.aciklama!.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(i.aciklama!, style: const TextStyle(height: 1.5)),
                      ],
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: Renk.cizgi,
                            child: Text(i.saticiAd.isEmpty ? '?' : i.saticiAd.substring(0, 1).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, color: Renk.yesil)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_benim ? 'Siz' : i.saticiAd, style: const TextStyle(fontWeight: FontWeight.w800)),
                                const Text('✓ Telefonu doğrulanmış', style: TextStyle(color: Renk.yesil, fontSize: 13, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ],
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
                            margin: const EdgeInsets.only(top: 8),
                            padding: const EdgeInsets.all(12),
                            width: double.infinity,
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Renk.cizgi)),
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
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Renk.cizgi))),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: SafeArea(
              top: false,
              child: _benim
                  ? Row(
                      children: [
                        if (i.aktif) ...[
                          Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)), onPressed: () => _durum('pasif', 'İlan yayından kaldırıldı'), child: const Text('Yayından kaldır'))),
                          const SizedBox(width: 10),
                          Expanded(child: FilledButton(onPressed: () => _durum('satildi', 'İlan satıldı olarak işaretlendi'), child: const Text('Satıldı'))),
                        ] else
                          Expanded(child: FilledButton(onPressed: () => _durum('aktif', 'İlan yeniden yayında'), child: const Text('Yeniden yayınla'))),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), side: const BorderSide(color: Renk.yesil)), onPressed: i.aktif ? _mesaj : null, child: const Text('Mesaj gönder'))),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => bildir(context, 'Satıcılar numaralarını paylaşmaz. Uygulama içinden mesaj gönderebilirsin.'),
                            child: const Text('Satıcıyı ara'),
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
