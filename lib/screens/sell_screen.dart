import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data.dart';
import '../konum.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// İlan verme: 4 adım (hayvan → yaş/ağırlık/fiyat → konum/belgeler → fotoğraf/açıklama).
/// Hatalar ilgili alanın altında gösterilir ve sayfa ilk hatalı alana kayar.
/// [duzenle] verilirse aynı form mevcut ilanı düzenler (fotoğraf ve video değişmez).
class SellScreen extends StatefulWidget {
  const SellScreen({super.key, this.duzenle});
  final Ilan? duzenle;

  @override
  State<SellScreen> createState() => _SellScreenState();
}

class _SellScreenState extends State<SellScreen> {
  static const adimAdlari = ['Hayvan', 'Yaş, ağırlık ve fiyat', 'Konum ve belgeler', 'Fotoğraf ve açıklama'];
  static const _turAciklama = {'Büyükbaş': 'Sığır, manda', 'Küçükbaş': 'Koyun, keçi', 'Kanatlı': 'Tavuk, hindi, kaz', 'At': 'At, midilli'};
  static const _turIkon = {
    'Büyükbaş': Icons.agriculture_outlined,
    'Küçükbaş': Icons.grass_rounded,
    'Kanatlı': Icons.egg_outlined,
    'At': Icons.pets_outlined,
  };

  int _adim = 0;
  String? _tur;
  String? _cins;
  String _cinsiyet = 'disi';
  bool _suru = false;
  int _adet = 10;
  String _satis = 'birlikte';
  String? _amac;
  final Set<String> _belgeler = {};
  bool _pazarlik = false;
  String _teslimat = 'yerinde';
  final _y1 = TextEditingController();
  final _y2 = TextEditingController();
  final _kg = TextEditingController();
  final _fiyat = TextEditingController();
  late String? _il = ilBul(app.profil?['il'] as String?)?.ad;
  late String? _ilce = ilceBul(_il, app.profil?['ilce'] as String?)?.ad;
  final _acik = TextEditingController();
  final List<FotoDosya> _fotolar = [];
  FotoDosya? _video;
  static const _videoLimit = 50 * 1024 * 1024;
  bool _yukleniyor = false;
  String? _hata;
  final Map<String, String?> _h = {};
  final Map<String, GlobalKey> _k = {for (final a in ['tur', 'cins', 'yas', 'kg', 'fiyat', 'konum', 'foto', 'aciklama']) a: GlobalKey()};
  final _kaydirma = ScrollController();

  int get _adetGercek => _suru ? _adet : 1;
  String? get _turKodu => _tur == null ? null : turKod[_tur];

  bool get _duzenleme => widget.duzenle != null;

  @override
  void initState() {
    super.initState();
    final i = widget.duzenle;
    if (i == null) return;
    String yaz(double d) => d == d.roundToDouble() ? d.toInt().toString() : d.toString();
    _tur = i.turAd;
    _cins = i.cins;
    _cinsiyet = i.cinsiyet;
    _suru = i.adet > 1;
    if (_suru) _adet = i.adet;
    _satis = i.satisSekli;
    _amac = i.amac;
    _belgeler.addAll(i.belgeler);
    _pazarlik = i.pazarlik;
    _teslimat = i.teslimat;
    _y1.text = '${i.yasMin}';
    _y2.text = '${i.yasMax}';
    _kg.text = yaz(i.agirlik);
    _fiyat.text = yaz(i.toplam);
    _acik.text = i.aciklama ?? '';
    _il = ilBul(i.il)?.ad ?? i.il;
    _ilce = ilceBul(_il, i.ilce)?.ad ?? i.ilce;
  }

  bool get _degisti =>
      _duzenleme ||
      _tur != null || _y1.text.isNotEmpty || _kg.text.isNotEmpty || _fiyat.text.isNotEmpty || _acik.text.isNotEmpty || _fotolar.isNotEmpty;

  String get _kgFiyat {
    final k = sayiOku(_kg.text);
    final t = sayiOku(_fiyat.text);
    if (k == null || t == null || k <= 0 || t <= 0) return 'Ağırlık ve fiyatı girince hesaplanır';
    return '${sayi(t / (_adetGercek * k))} ₺/kg · $_adetGercek baş × ${sayi(k)} kg';
  }

  @override
  void dispose() {
    for (final c in [_y1, _y2, _kg, _fiyat, _acik]) {
      c.dispose();
    }
    _kaydirma.dispose();
    super.dispose();
  }

  // ---------------- Doğrulama ----------------

  bool _dogrula(int adim) {
    final h = <String, String?>{};
    switch (adim) {
      case 0:
        if (_tur == null) h['tur'] = 'Hayvan türünü seç.';
        if (_tur != null && _cins == null) h['cins'] = 'Cinsi seç.';
      case 1:
        final y1 = int.tryParse(_y1.text.trim());
        final y2 = _suru ? int.tryParse(_y2.text.trim()) : y1;
        if (y1 == null || y1 <= 0) {
          h['yas'] = _suru ? 'En küçük yaşı ay olarak yaz.' : 'Yaşı ay olarak yaz (1 yaş = 12 ay).';
        } else if (_suru && (y2 == null || y2 < y1)) {
          h['yas'] = 'En büyük yaş, en küçükten az olamaz.';
        } else if ((y2 ?? y1) > 360) {
          h['yas'] = 'En fazla 360 ay (30 yıl) girilebilir.';
        }
        final kg = sayiOku(_kg.text);
        final top = sayiOku(_fiyat.text);
        if (kg == null || kg <= 0) {
          h['kg'] = _suru ? 'Ortalama ağırlığı yaz.' : 'Canlı ağırlığı yaz.';
        } else {
          h['kg'] = agirlikMakul(_turKodu!, kg.toDouble());
        }
        if (top == null || top <= 0) {
          h['fiyat'] = 'Toplam fiyatı yaz.';
        } else if (h['kg'] == null && kg != null) {
          h['fiyat'] = fiyatMakul(_turKodu!, _adetGercek, kg.toDouble(), top.toDouble());
        }
      case 2:
        if (_il == null || _ilce == null) h['konum'] = 'Hayvanın bulunduğu il ve ilçeyi seç.';
      case 3:
        if (!_duzenleme && _fotolar.length < 3) h['foto'] = 'En az 3 fotoğraf ekle (şu an ${_fotolar.length}).';
        final riskli = metinSupheli(_acik.text);
        if (riskli.contains('IBAN') || riskli.contains('Telefon numarası')) {
          h['aciklama'] = 'Açıklamaya telefon numarası veya IBAN yazma. Alıcılar sana uygulamadan mesaj atar; numaran gizli kalır.';
        }
    }
    h.removeWhere((_, v) => v == null);
    setState(() {
      _h
        ..clear()
        ..addAll(h);
    });
    if (h.isEmpty) return true;
    final ilk = _k[h.keys.first]?.currentContext;
    if (ilk != null) {
      Scrollable.ensureVisible(ilk, duration: Hareket.azalt(context) ? Duration.zero : const Duration(milliseconds: 280), curve: Hareket.cikis, alignment: .15);
    }
    return false;
  }

  Future<void> _devam() async {
    if (!_dogrula(_adim)) return;
    if (_adim == 3) {
      if (metinSupheli(_acik.text).contains('Kapora / ön ödeme')) {
        final ok = await onayIste(
          context,
          'Açıklamada kapora / ön ödeme geçiyor',
          'Alıcıdan hayvanı görmeden kapora, havale veya EFT istemek şikâyet sebebidir ve ilanın gizlenebilir. Yine de yayınlansın mı?',
          'Yine de yayınla',
        );
        if (!ok || !mounted) return;
      }
      _yayinla();
      return;
    }
    setState(() {
      _adim++;
      _hata = null;
    });
    if (_kaydirma.hasClients) _kaydirma.jumpTo(0);
  }

  void _geri() {
    if (_adim == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() {
      _adim--;
      _h.clear();
    });
    if (_kaydirma.hasClients) _kaydirma.jumpTo(0);
  }

  // ---------------- Medya ----------------

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
      if (mounted) setState(() => _h.remove('foto'));
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

  // ---------------- Yayınla ----------------

  Future<void> _yayinla() async {
    final y1 = int.parse(_y1.text.trim());
    final y2 = _suru ? int.parse(_y2.text.trim()) : y1;
    setState(() {
      _hata = null;
      _yukleniyor = true;
    });
    final alanlar = <String, dynamic>{
        'tur': _turKodu,
        'cins': _cins,
        'cinsiyet': _cinsiyet,
        'adet': _adetGercek,
        'yas_min': y1,
        'yas_max': y2,
        'agirlik_kg': sayiOku(_kg.text),
        'toplam_fiyat': sayiOku(_fiyat.text),
        'satis_sekli': _suru ? _satis : 'birlikte',
        'aciklama': _acik.text.trim().isEmpty ? null : _acik.text.trim(),
        'il': _il,
        'ilce': _ilce,
        'amac': _amac,
        'belgeler': _belgeler.toList(),
        'pazarlik': _pazarlik,
        'teslimat': _teslimat,
    };
    try {
      if (_duzenleme) {
        final i = widget.duzenle!;
        await ilanGuncelle(i.id, alanlar);
        final onayda = await ilanOnayBekliyor(i.id);
        app.ilanlariYenile();
        if (!mounted) return;
        Navigator.of(context).pop(true);
        bildir(context, onayda ? 'Değişiklikler kaydedildi. İlan yönetici onayından sonra yayına çıkacak.' : 'Değişiklikler kaydedildi.');
        return;
      }
      final yeniId = await ilanVer({'seller_id': uid, ...alanlar}, _fotolar, video: _video);
      final onayda = await ilanOnayBekliyor(yeniId);
      app.filtre = Filtre();
      app.arama = '';
      app.sekme = 0;
      app.ilanlariYenile();
      if (!mounted) return;
      Navigator.of(context).pop();
      bildir(context, onayda ? 'İlanın alındı. Yönetici onayından sonra yayına çıkacak.' : 'İlanın yayınlandı. İlan sayfasındaki paylaş düğmesiyle WhatsApp\'ta paylaşabilirsin.');
    } on PostgrestException catch (e) {
      setState(() => _hata = '${_duzenleme ? 'Kaydedilemedi' : 'İlan yayınlanamadı'}: ${e.message}');
    } catch (err) {
      setState(() => _hata = '${_duzenleme ? 'Kaydedilemedi' : 'İlan yayınlanamadı'}: $err');
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  // ---------------- Görünüm ----------------

  Widget _bolum(String t, {double ust = 22}) => Padding(
        padding: EdgeInsets.only(top: ust, bottom: 10),
        child: Semantics(header: true, child: Text(t, style: baslik(20))),
      );

  Widget _etiket(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)));

  Widget _hataYazi(String a) => _h[a] == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(top: 6, left: 4),
          child: Text(_h[a]!, style: const TextStyle(color: uyariRenk, fontWeight: FontWeight.w700, fontSize: 13)),
        );

  InputDecoration _alan(String etiket, String ornek, String a, {String? son}) => InputDecoration(
        labelText: etiket,
        hintText: ornek,
        hintStyle: const TextStyle(color: Color(0x803A3220)),
        suffixText: son,
        errorText: _h[a],
        errorMaxLines: 3,
      );

  Widget _turKarti(String t, double genislik) {
    final secili = _tur == t;
    return SizedBox(
      width: genislik,
      child: Semantics(
        button: true,
        selected: secili,
        label: t,
        excludeSemantics: true,
        onTap: () => _turSec(t),
        child: Basma(
          child: GestureDetector(
            onTap: () => _turSec(t),
            child: AnimatedContainer(
              duration: Hareket.renk,
              constraints: const BoxConstraints(minHeight: 96),
              padding: const EdgeInsets.all(14),
              decoration: secili
                  ? BoxDecoration(color: Renk.yesil, borderRadius: BorderRadius.circular(18), boxShadow: Golge.kart)
                  : kutu(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(_turIkon[t], color: secili ? Renk.krem : Renk.yesil, size: 26),
                const SizedBox(height: 8),
                Text(t, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: secili ? Renk.krem : Renk.murekkep)),
                Text(_turAciklama[t] ?? '', style: TextStyle(fontSize: 13, color: secili ? Renk.krem.withValues(alpha: .85) : Renk.soluk)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  void _turSec(String t) => setState(() {
        if (_tur != t) _cins = null;
        _tur = t;
        _h.remove('tur');
      });

  List<Widget> _adim0() {
    final liste = cinsListesi[_tur] ?? [];
    // Düzenlenen ilanın cinsi listede yoksa (eski kayıt) yine de seçili görünsün.
    final cinsler = [...liste, if (_cins != null && !liste.contains(_cins)) _cins!];
    return [
      _bolum('Hangi hayvanı satıyorsun?', ust: 4),
      KeyedSubtree(
        key: _k['tur'],
        child: LayoutBuilder(builder: (c, k) {
          final g = (k.maxWidth - 10) / 2;
          return Wrap(spacing: 10, runSpacing: 10, children: [for (final t in turSecenekleri) _turKarti(t, g)]);
        }),
      ),
      _hataYazi('tur'),
      if (_tur != null) ...[
        const SizedBox(height: 18),
        KeyedSubtree(
          key: _k['cins'],
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _etiket('Cins'),
            Wrap(runSpacing: 8, children: [
              for (final c in cinsler)
                Cip(c, _cins == c, () => setState(() {
                      _cins = c;
                      _h.remove('cins');
                    })),
            ]),
            _hataYazi('cins'),
          ]),
        ),
        const SizedBox(height: 18),
        _etiket('Tek hayvan mı, sürü mü?'),
        Wrap(runSpacing: 8, children: [
          Cip('Tek hayvan', !_suru, () => setState(() {
                _suru = false;
                if (_cinsiyet == 'karisik') _cinsiyet = 'disi';
              })),
          Cip('Sürü (birden fazla)', _suru, () => setState(() => _suru = true)),
        ]),
        if (_suru) ...[
          const SizedBox(height: 14),
          _etiket('Kaç baş?'),
          Container(
            height: 56,
            decoration: kutu(14.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(tooltip: 'Azalt', onPressed: () => setState(() => _adet = (_adet - 1).clamp(2, 5000)), icon: const Icon(Icons.remove)),
                Text('$_adet baş', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                IconButton(tooltip: 'Artır', onPressed: () => setState(() => _adet = (_adet + 1).clamp(2, 5000)), icon: const Icon(Icons.add)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _etiket('Satış şekli'),
          Wrap(runSpacing: 8, children: [
            Cip('Toplu satılır', _satis == 'birlikte', () => setState(() => _satis = 'birlikte')),
            Cip('Adet adet de satılır', _satis == 'adet_adet', () => setState(() => _satis = 'adet_adet')),
          ]),
        ],
        const SizedBox(height: 18),
        _etiket('Cinsiyet'),
        Wrap(runSpacing: 8, children: [
          for (final e in cinsiyetEtiket.entries)
            if (_suru || e.key != 'karisik') Cip(e.value, _cinsiyet == e.key, () => setState(() => _cinsiyet = e.key)),
        ]),
      ],
    ];
  }

  List<Widget> _adim1() => [
        _bolum('Yaş, ağırlık ve fiyat', ust: 4),
        KeyedSubtree(
          key: _k['yas'],
          child: _suru
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: TextField(controller: _y1, keyboardType: TextInputType.number, decoration: _alan('En küçük yaş', 'örn. 8', 'yas', son: 'ay'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: _y2, keyboardType: TextInputType.number, decoration: _alan('En büyük yaş', 'örn. 14', '-', son: 'ay'))),
                ])
              : TextField(controller: _y1, keyboardType: TextInputType.number, decoration: _alan('Yaş (ay)', 'örn. 18', 'yas', son: 'ay')),
        ),
        const Padding(padding: EdgeInsets.only(top: 4, left: 4), child: Text('1 yaş = 12 ay', style: TextStyle(color: Renk.soluk, fontSize: 12))),
        const SizedBox(height: 14),
        KeyedSubtree(
          key: _k['kg'],
          child: TextField(
            controller: _kg,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: _alan(_suru ? 'Ortalama ağırlık (kg)' : 'Canlı ağırlık (kg)', _tur == 'Büyükbaş' ? 'örn. 420' : 'örn. 45', 'kg', son: 'kg'),
          ),
        ),
        const SizedBox(height: 14),
        KeyedSubtree(
          key: _k['fiyat'],
          child: TextField(
            controller: _fiyat,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: _alan(_suru ? 'Toplam fiyat (tüm sürü, ₺)' : 'Toplam fiyat (₺)', _tur == 'Büyükbaş' ? 'örn. 145000' : 'örn. 18000', 'fiyat', son: '₺'),
          ),
        ),
        const SizedBox(height: 14),
        _etiket('Kg fiyatı (otomatik)'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Renk.zemin2, borderRadius: BorderRadius.circular(12)),
          child: Text(_kgFiyat, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _pazarlik,
          activeTrackColor: Renk.yesil,
          onChanged: (v) => setState(() => _pazarlik = v),
          title: const Text('Pazarlık payı var', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: const Text('Alıcılar sana teklif gönderebilir'),
        ),
      ];

  List<Widget> _adim2() => [
        _bolum('Hayvan nerede?', ust: 4),
        KeyedSubtree(
          key: _k['konum'],
          child: KonumAlani(
            il: _il,
            ilce: _ilce,
            hata: _h['konum'],
            secildi: (il, ilce) => setState(() {
              _il = il;
              _ilce = ilce;
              _h.remove('konum');
            }),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(top: 6, left: 4),
          child: Text('Alıcılar ilçeni görür, tam adresin gizli kalır. Yakınındaki alıcılar seni mesafeye göre bulur.', style: TextStyle(color: Renk.soluk, fontSize: 13)),
        ),
        _bolum('Teslimat'),
        Wrap(runSpacing: 8, children: [
          for (final e in teslimatEtiket.entries) Cip(e.value, _teslimat == e.key, () => setState(() => _teslimat = e.key)),
        ]),
        _bolum('Satış amacı (isteğe bağlı)'),
        Wrap(runSpacing: 8, children: [
          for (final e in amacEtiket.entries) Cip(e.value, _amac == e.key, () => setState(() => _amac = _amac == e.key ? null : e.key)),
        ]),
        _bolum('Elindeki belgeler'),
        const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Belgeli ilanlar alıcıya güven verir ve listede rozetle görünür.', style: TextStyle(color: Renk.soluk, fontSize: 13))),
        Wrap(runSpacing: 8, children: [
          for (final e in belgeEtiket.entries)
            Cip(e.value, _belgeler.contains(e.key), () => setState(() => _belgeler.contains(e.key) ? _belgeler.remove(e.key) : _belgeler.add(e.key))),
        ]),
      ];

  List<Widget> _adim3() => [
        _bolum('Fotoğraf ve açıklama', ust: 4),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Renk.okZemin, borderRadius: BorderRadius.circular(14)),
          child: Text(
            '${_cins ?? ''} · $_adetGercek baş · ${_kg.text} kg · ${tl(sayiOku(_fiyat.text) ?? 0)}${_il == null ? '' : ' · ${konumYaz(_il!, _ilce)}'}',
            style: const TextStyle(color: Renk.okYazi, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 14),
        if (_duzenleme) ...[
          _etiket('Fotoğraflar'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final u in widget.duzenle!.foto)
              ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(u, width: 82, height: 82, fit: BoxFit.cover)),
          ]),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Fotoğraf ve video düzenlemede değişmez. Değiştirmek için ilanı silip yeniden ver.', style: TextStyle(color: Renk.soluk, fontSize: 13)),
          ),
        ] else ...[
        KeyedSubtree(key: _k['foto'], child: _etiket('Fotoğraflar (en az 3, en fazla 8)')),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Semantics(
              button: true,
              label: 'Fotoğraf ekle',
              child: InkWell(
                onTap: _fotolar.length >= 8 ? null : _fotoEkle,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    color: Renk.kart,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _h['foto'] != null ? uyariRenk : Renk.soluk, width: 1.5),
                  ),
                  child: Icon(Icons.add_a_photo_outlined, color: _h['foto'] != null ? uyariRenk : Renk.soluk),
                ),
              ),
            ),
            for (var i = 0; i < _fotolar.length; i++)
              Stack(
                children: [
                  ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(_fotolar[i].bytes, width: 82, height: 82, fit: BoxFit.cover)),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Semantics(
                      button: true,
                      label: 'Fotoğrafı kaldır',
                      child: GestureDetector(
                        onTap: () => setState(() => _fotolar.removeAt(i)),
                        child: Container(
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          padding: const EdgeInsets.all(3),
                          child: const Icon(Icons.close, color: Colors.white, size: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        _hataYazi('foto'),
        ],
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Renk.kupe, borderRadius: BorderRadius.circular(10)),
          child: const Text(
            'Kendi hayvanının güncel fotoğraflarını yükle. Başka ilandan alınan fotoğraf şikâyet sebebidir. Fotoğrafa veya açıklamaya IBAN ve telefon yazma; alıcıdan kapora isteme.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
        ),
        const SizedBox(height: 16),
        if (!_duzenleme) _etiket('Video (isteğe bağlı · en fazla 60 sn, 50 MB)'),
        if (_duzenleme)
          const SizedBox.shrink()
        else if (_video == null)
          OutlinedButton.icon(onPressed: _videoEkle, icon: const Icon(Icons.videocam_outlined), label: const Text('Video ekle'))
        else
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
            decoration: kutu(14.0),
            child: Row(
              children: [
                const Icon(Icons.videocam, color: Renk.yesil),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('${_video!.ad} · ${(_video!.bytes.length / 1048576).toStringAsFixed(1)} MB',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                IconButton(tooltip: 'Videoyu kaldır', onPressed: () => setState(() => _video = null), icon: const Icon(Icons.close)),
              ],
            ),
          ),
        const SizedBox(height: 16),
        TextField(
          key: _k['aciklama'],
          controller: _acik,
          maxLines: 4,
          maxLength: 2000,
          onChanged: (_) {
            if (_h.containsKey('aciklama')) setState(() => _h.remove('aciklama'));
          },
          decoration: InputDecoration(
            labelText: 'Açıklama (isteğe bağlı)',
            hintText: 'Sağlık durumu, aşılar, besleme, gebelik, teslim şekli…',
            alignLabelWithHint: true,
            errorText: _h['aciklama'],
            errorMaxLines: 3,
          ),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final icerik = switch (_adim) { 0 => _adim0(), 1 => _adim1(), 2 => _adim2(), _ => _adim3() };
    return PopScope(
      canPop: !_degisti || _yukleniyor,
      onPopInvokedWithResult: (cikti, _) async {
        if (cikti) return;
        final ok = await onayIste(context, 'İlandan çıkılsın mı?', 'Girdiğin bilgiler kaydedilmez.', 'Çık', tehlike: true);
        // Navigator.pop, PopScope'a takılmadan kapatır
        if (ok && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(children: [
            Flexible(child: Text(_duzenleme ? 'İlanı düzenle' : 'İlan ver', maxLines: 1, overflow: TextOverflow.ellipsis)),
            if (_suru)
              Container(
                margin: const EdgeInsets.only(left: 10),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(color: altin, borderRadius: BorderRadius.circular(8)),
                child: const Text('Sürü ilanı', style: TextStyle(color: Renk.murekkep, fontSize: 12, fontWeight: FontWeight.w800)),
              ),
          ]),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(34),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Semantics(
                label: 'Adım ${_adim + 1} / 4: ${adimAdlari[_adim]}',
                excludeSemantics: true,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    for (var i = 0; i < 4; i++)
                      Expanded(
                        child: AnimatedContainer(
                          duration: Hareket.gosterge,
                          curve: Hareket.cikis,
                          height: 5,
                          margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
                          decoration: BoxDecoration(color: i <= _adim ? Renk.yesil : Renk.zemin2, borderRadius: BorderRadius.circular(9)),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 6),
                  Text('Adım ${_adim + 1}/4 · ${adimAdlari[_adim]}', style: const TextStyle(color: Renk.soluk, fontWeight: FontWeight.w700, fontSize: 13)),
                ]),
              ),
            ),
          ),
        ),
        body: ListView(
          controller: _kaydirma,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            ...icerik,
            if (_hata != null)
              Padding(padding: const EdgeInsets.only(top: 12), child: Text(_hata!, style: const TextStyle(color: uyariRenk, fontWeight: FontWeight.w700))),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(color: Renk.kart.withValues(alpha: .97), border: const Border(top: BorderSide(color: Renk.ayrac))),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: SafeArea(
            top: false,
            child: Row(children: [
              if (_adim > 0) ...[
                Expanded(child: OutlinedButton(onPressed: _yukleniyor ? null : _geri, child: const Text('Geri'))),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 2,
                child: Basma(
                  child: FilledButton(
                    onPressed: _yukleniyor ? null : _devam,
                    child: _yukleniyor
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_adim == 3 ? (_duzenleme ? 'Kaydet' : 'İlanı yayınla') : 'Devam'),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
