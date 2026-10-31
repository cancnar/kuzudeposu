import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

class SellScreen extends StatefulWidget {
  const SellScreen({super.key});

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  String _tur = 'Büyükbaş';
  String? _cins;
  String _cinsiyet = 'disi';
  int _adet = 1;
  String _satis = 'birlikte';
  String? _amac;
  final Set<String> _belgeler = {};
  bool _pazarlik = false;
  String _teslimat = 'yerinde';
  final _y1 = TextEditingController();
  final _y2 = TextEditingController();
  final _kg = TextEditingController();
  final _fiyat = TextEditingController();
  late final TextEditingController _il = TextEditingController(text: app.profil?['il'] as String? ?? '');
  late final TextEditingController _ilce = TextEditingController(text: app.profil?['ilce'] as String? ?? '');
  final _acik = TextEditingController();
  final List<FotoDosya> _fotolar = [];
  FotoDosya? _video;
  static const _videoLimit = 50 * 1024 * 1024;
  bool _yukleniyor = false;
  String? _hata;

  bool get _suru => _adet > 1;

  String get _kgFiyat {
    final k = sayiOku(_kg.text);
    final t = sayiOku(_fiyat.text);
    if (k == null || t == null || k <= 0 || t <= 0) return 'Ağırlık ve fiyat girince hesaplanır';
    return '${sayi(t / (_adet * k))} ₺/kg · $_adet baş × ${sayi(k)} kg';
  }

  Future<void> _fotoEkle() async {
    try {
      final secilen = await ImagePicker().pickMultiImage(imageQuality: 80, maxWidth: 1600);
      for (final x in secilen) {
        if (_fotolar.length >= 8) break;
        final ad = x.name;
        final uz = ad.contains('.') ? ad.split('.').last.toLowerCase() : 'jpg';
        final tip = switch (uz) { 'png' => 'image/png', 'webp' => 'image/webp', _ => 'image/jpeg' };
        _fotolar.add(FotoDosya(await x.readAsBytes(), ad, tip));
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) bildir(context, 'Fotoğraf seçilemedi: $e');
    }
  }

  Future<void> _videoEkle() async {
    try {
      final x = await ImagePicker().pickVideo(source: ImageSource.gallery, maxDuration: const Duration(seconds: 60));
      if (x == null) return;
      final b = await x.readAsBytes();
      if (b.length > _videoLimit) {
        if (mounted) setState(() => _hata = 'Video en fazla 50 MB olabilir (seçilen: ${(b.length / 1048576).toStringAsFixed(0)} MB). Daha kısa çekmeyi dene.');
        return;
      }
      if (mounted) {
        setState(() {
          _video = FotoDosya(b, x.name, videoTipi(x.name));
          _hata = null;
        });
      }
    } catch (e) {
      if (mounted) bildir(context, 'Video seçilemedi: $e');
    }
  }

  Future<void> _yayinla() async {
    final y1 = int.tryParse(_y1.text.trim());
    final y2 = _suru ? int.tryParse(_y2.text.trim()) : y1;
    final kg = sayiOku(_kg.text);
    final top = sayiOku(_fiyat.text);
    String? e;
    if (_cins == null) {
      e = 'Cins seç.';
    } else if (y1 == null || y1 <= 0) {
      e = _suru ? 'En küçük yaşı gir.' : 'Yaşı gir.';
    } else if (_suru && (y2 == null || y2 < y1)) {
      e = 'En büyük yaş, en küçükten az olamaz.';
    } else if (kg == null || kg <= 0) {
      e = _suru ? 'Ortalama ağırlığı gir.' : 'Canlı ağırlığı gir.';
    } else if (top == null || top <= 0) {
      e = 'Toplam fiyatı gir.';
    } else if (_il.text.trim().isEmpty || _ilce.text.trim().isEmpty) {
      e = 'İl ve ilçeyi gir.';
    } else if (_fotolar.length < 3) {
      e = 'En az 3 fotoğraf ekle.';
    }
    if (e != null) {
      setState(() => _hata = e);
      return;
    }
    setState(() {
      _hata = null;
      _yukleniyor = true;
    });
    try {
      await ilanVer({
        'seller_id': uid,
        'tur': turKod[_tur],
        'cins': _cins,
        'cinsiyet': _cinsiyet,
        'adet': _adet,
        'yas_min': y1,
        'yas_max': y2,
        'agirlik_kg': kg,
        'toplam_fiyat': top,
        'satis_sekli': _suru ? _satis : 'birlikte',
        'aciklama': _acik.text.trim().isEmpty ? null : _acik.text.trim(),
        'il': _il.text.trim(),
        'ilce': _ilce.text.trim(),
        'amac': _amac,
        'belgeler': _belgeler.toList(),
        'pazarlik': _pazarlik,
        'teslimat': _teslimat,
      }, _fotolar, video: _video);
      app.filtre = Filtre();
      app.arama = '';
      app.sekme = 0;
      app.ilanlariYenile();
      if (!mounted) return;
      Navigator.of(context).pop();
      bildir(context, 'İlanın yayınlandı');
    } catch (err) {
      setState(() => _hata = 'İlan yayınlanamadı: $err\n(Fotoğraf yükleme hatasıysa 002, video hatasıysa 007_video.sql çalıştırıldı mı?)');
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Widget _bolum(String t, {double ust = 22}) => Padding(
        padding: EdgeInsets.only(top: ust, bottom: 10),
        child: Row(children: [
          Container(width: 4, height: 18, decoration: BoxDecoration(color: Renk.kiremit, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(t, style: baslik(18)),
        ]),
      );

  Widget _etiket(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)));

  @override
  Widget build(BuildContext context) {
    final cinsler = cinsListesi[_tur] ?? [];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('İlan ver'),
            if (_suru)
              Container(
                margin: const EdgeInsets.only(left: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: altin, borderRadius: BorderRadius.circular(8)),
                child: const Text('Sürü ilanı', style: TextStyle(color: Renk.murekkep, fontSize: 12, fontWeight: FontWeight.w800)),
              ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _bolum('Hayvan bilgileri', ust: 4),
          _etiket('Hayvan türü'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final t in turSecenekleri)
                Cip(t, _tur == t, () => setState(() {
                      _tur = t;
                      _cins = null;
                    })),
            ]),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _etiket('Cins'),
                  DropdownButtonFormField<String>(
                    value: _cins,
                    isExpanded: true,
                    hint: const Text('Seç'),
                    items: [for (final c in cinsler) DropdownMenuItem(value: c, child: Text(c))],
                    onChanged: (v) => setState(() => _cins = v),
                  ),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _etiket('Cinsiyet'),
                  DropdownButtonFormField<String>(
                    value: _cinsiyet,
                    isExpanded: true,
                    items: [for (final e in cinsiyetEtiket.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                    onChanged: (v) => setState(() => _cinsiyet = v ?? 'disi'),
                  ),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _etiket('Hayvan adedi'),
                  Container(
                    height: 56,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Renk.cizgi)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(tooltip: 'Azalt', onPressed: () => setState(() => _adet = (_adet - 1).clamp(1, 500)), icon: const Icon(Icons.remove)),
                        Text('$_adet', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                        IconButton(tooltip: 'Artır', onPressed: () => setState(() => _adet = (_adet + 1).clamp(1, 500)), icon: const Icon(Icons.add)),
                      ],
                    ),
                  ),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _etiket(_suru ? 'Yaş aralığı (ay)' : 'Yaş (ay)'),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: _y1, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: _suru ? '12' : '18'))),
                      if (_suru) ...[
                        const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('–')),
                        Expanded(child: TextField(controller: _y2, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: '24'))),
                      ],
                    ],
                  ),
                ]),
              ),
            ],
          ),
          if (_suru) ...[
            const SizedBox(height: 14),
            _etiket('Satış şekli'),
            Wrap(children: [
              Cip('Toplu satılır', _satis == 'birlikte', () => setState(() => _satis = 'birlikte')),
              Cip('Adet adet de satılır', _satis == 'adet_adet', () => setState(() => _satis = 'adet_adet')),
            ]),
          ],
          _bolum('Fiyat ve konum'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _etiket(_suru ? 'Ortalama ağırlık (kg)' : 'Canlı ağırlık (kg)'),
                  TextField(controller: _kg, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: '420')),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _etiket('Toplam fiyat (₺)'),
                  TextField(controller: _fiyat, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: '145000')),
                ]),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _etiket('Kg fiyatı (otomatik)'),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFF1EBD6), borderRadius: BorderRadius.circular(12)),
            child: Text(_kgFiyat, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: TextField(controller: _il, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'İl'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _ilce, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'İlçe'))),
            ],
          ),
          _bolum('Amaç, belge ve teslimat'),
          _etiket('Satış amacı (isteğe bağlı)'),
          Wrap(runSpacing: 8, children: [
            for (final e in amacEtiket.entries) Cip(e.value, _amac == e.key, () => setState(() => _amac = _amac == e.key ? null : e.key)),
          ]),
          const SizedBox(height: 14),
          _etiket('Elindeki belgeler (alıcıya güven verir)'),
          Wrap(runSpacing: 8, children: [
            for (final e in belgeEtiket.entries)
              Cip(e.value, _belgeler.contains(e.key), () => setState(() => _belgeler.contains(e.key) ? _belgeler.remove(e.key) : _belgeler.add(e.key))),
          ]),
          const SizedBox(height: 14),
          _etiket('Teslimat'),
          Wrap(runSpacing: 8, children: [
            for (final e in teslimatEtiket.entries) Cip(e.value, _teslimat == e.key, () => setState(() => _teslimat = e.key)),
          ]),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _pazarlik,
            activeColor: Renk.yesil,
            onChanged: (v) => setState(() => _pazarlik = v),
            title: const Text('Pazarlık payı var', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Alıcılar sana mesajla teklif gönderebilir'),
          ),
          _bolum('Açıklama ve fotoğraflar'),
          TextField(controller: _acik, maxLines: 3, maxLength: 2000, decoration: const InputDecoration(labelText: 'Açıklama (isteğe bağlı)', alignLabelWithHint: true)),
          const SizedBox(height: 6),
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFFFF3D6), borderRadius: BorderRadius.circular(10), border: Border.all(color: altin)),
            child: const Text('Kendi hayvanının, güncel fotoğraflarını yükle. Başka ilandan alınan fotoğraf şikayet sebebidir ve ilan kaldırılır. Alıcıdan kapora isteme.', style: TextStyle(fontSize: 13, height: 1.4)),
          ),
          _etiket('Fotoğraflar (en az 3, en fazla 8)'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              InkWell(
                onTap: _fotolar.length >= 8 ? null : _fotoEkle,
                child: Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Renk.soluk, width: 1.5)),
                  child: const Icon(Icons.add_a_photo_outlined, color: Renk.soluk),
                ),
              ),
              for (var i = 0; i < _fotolar.length; i++)
                Stack(
                  children: [
                    ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(_fotolar[i].bytes, width: 82, height: 82, fit: BoxFit.cover)),
                    Positioned(
                      right: 0,
                      top: 0,
                      child: GestureDetector(
                        onTap: () => setState(() => _fotolar.removeAt(i)),
                        child: Container(
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          padding: const EdgeInsets.all(3),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 16),
          _etiket('Video (isteğe bağlı · en fazla 60 sn, 50 MB)'),
          if (_video == null)
            OutlinedButton.icon(onPressed: _videoEkle, icon: const Icon(Icons.videocam_outlined), label: const Text('Video ekle'))
          else
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Renk.cizgi)),
              child: Row(
                children: [
                  const Icon(Icons.videocam, color: Renk.yesil),
                  const SizedBox(width: 10),
                  Expanded(child: Text('${_video!.ad} · ${(_video!.bytes.length / 1048576).toStringAsFixed(1)} MB', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                  IconButton(tooltip: 'Videoyu kaldır', onPressed: () => setState(() => _video = null), icon: const Icon(Icons.close)),
                ],
              ),
            ),
          if (_hata != null)
            Padding(padding: const EdgeInsets.only(top: 12), child: Text(_hata!, style: const TextStyle(color: uyariRenk, fontWeight: FontWeight.w700))),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _yukleniyor ? null : _yayinla,
            child: _yukleniyor
                ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('İlanı yayınla'),
          ),
        ],
      ),
    );
  }
}
