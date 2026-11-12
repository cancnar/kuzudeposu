import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets.dart';
import '../yonetim.dart';
import 'detail_screen.dart';

const _uyariZemin = Color(0xFFF7E3DC);

/// Dolgulu ikincil buton (zemin2) — tam genişlik.
Widget _ikincil(String yazi, VoidCallback? onTap, {IconData? ikon, Color renk = Renk.yesil}) => Basma(
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(foregroundColor: renk),
        icon: Icon(ikon ?? Icons.chevron_right_rounded, size: 20),
        label: Text(yazi),
      ),
    );

Widget _birincil(String yazi, VoidCallback? onTap, {IconData? ikon, Color renk = Renk.yesil}) => Basma(
      child: FilledButton.icon(
        onPressed: onTap,
        style: FilledButton.styleFrom(backgroundColor: renk),
        icon: Icon(ikon ?? Icons.check_rounded, size: 20),
        label: Text(yazi),
      ),
    );

/// Küçük etiket (durum, şüphe nedeni, şikâyet sayısı)
class Etiket extends StatelessWidget {
  const Etiket(this.yazi, {super.key, this.uyari = false, this.ikon});
  final String yazi;
  final bool uyari;
  final IconData? ikon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: uyari ? _uyariZemin : Renk.zemin2, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (ikon != null) ...[Icon(ikon, size: 14, color: uyari ? Renk.kiremit : Renk.soluk), const SizedBox(width: 4)],
          Flexible(
            child: Text(yazi,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: uyari ? Renk.kiremit : Renk.murekkep)),
          ),
        ]),
      );
}

/// Gerekçe sorar: hazır seçenekler + isteğe bağlı açıklama. Vazgeçilirse null.
Future<String?> nedenSor(BuildContext context, String baslikYazi, List<String> secenekler, {String dugme = 'Devam'}) {
  String? secim;
  final ek = TextEditingController();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Renk.krem,
    sheetAnimationStyle: Hareket.altSayfa(context),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (c) => StatefulBuilder(
      builder: (c, yenile) {
        final hazir = secim != null || ek.text.trim().isNotEmpty;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 16 + MediaQuery.of(c).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(baslikYazi, style: baslik(22)),
              const SizedBox(height: 4),
              const Text('Kullanıcıya bildirimde bu gerekçe gösterilir.', style: TextStyle(color: Renk.soluk)),
              const SizedBox(height: 14),
              Wrap(children: [for (final s in secenekler) Cip(s, secim == s, () => yenile(() => secim = secim == s ? null : s))]),
              const SizedBox(height: 12),
              TextField(
                controller: ek,
                maxLines: 2,
                maxLength: 300,
                onChanged: (_) => yenile(() {}),
                decoration: const InputDecoration(labelText: 'Açıklama (isteğe bağlı)'),
              ),
              const SizedBox(height: 8),
              _birincil(dugme, hazir
                  ? () {
                      final t = ek.text.trim();
                      Navigator.of(c).pop([if (secim != null) secim!, if (t.isNotEmpty) t].join(': '));
                    }
                  : null, renk: Renk.kiremit),
            ]),
          ),
        );
      },
    ),
  );
}

const ilanGerekceleri = [
  'Başka hayvanın fotoğrafı',
  'Sahte veya yanıltıcı ilan',
  'Kapora / ön ödeme istiyor',
  'İletişim bilgisi veya IBAN paylaşmış',
  'Uygunsuz içerik',
  'Diğer',
];
const askiGerekceleri = ['Dolandırıcılık şüphesi', 'Kapora istiyor', 'Sahte ilanlar', 'Hakaret / taciz', 'Tekrarlayan kural ihlali', 'Diğer'];

/// İşlemi yapar, sonucu alttan bildirir. Başarılıysa true.
Future<bool> _yap(BuildContext c, Future<void> Function() f, String mesaj) async {
  try {
    await f();
    if (c.mounted) bildir(c, mesaj);
    return true;
  } catch (e) {
    if (c.mounted) bildir(c, 'İşlem yapılamadı: ${'$e'.replaceFirst(RegExp(r'^.*message: '), '').split(', code:').first}');
    return false;
  }
}

/// İlan için yönetici işlemleri (alt sayfa). İşlem yapılırsa true döner.
Future<bool> ilanIslemSayfasi(BuildContext context, YIlan y) async {
  final i = y.ilan;
  final m = i.moderasyon;
  final sonuc = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Renk.krem,
    sheetAnimationStyle: Hareket.altSayfa(context),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (c) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(i.cins, style: baslik(22)),
          const SizedBox(height: 4),
          Text('${i.turAd} · ${i.adet} baş · ${i.yer} · ${tl(i.toplam)}', style: const TextStyle(color: Renk.soluk)),
          Text('Satıcı: ${i.saticiAd}${y.saticiAskida ? ' (askıda)' : ''} · ${goreli(i.olusturma)}', style: const TextStyle(color: Renk.soluk)),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            Etiket(i.durumAd, uyari: m != null),
            for (final n in y.nedenler) Etiket(n, uyari: true, ikon: Icons.warning_amber_rounded),
            if (y.sikayet > 0) Etiket('${y.sikayet} açık şikâyet', uyari: true, ikon: Icons.flag_outlined),
          ]),
          if (i.moderasyonNeden != null) ...[
            const SizedBox(height: 10),
            Text('Gerekçe: ${i.moderasyonNeden}', style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
          if ((i.aciklama ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Renk.zemin2, borderRadius: BorderRadius.circular(12)),
              child: Text(i.aciklama!, style: const TextStyle(height: 1.4)),
            ),
          ],
          const SizedBox(height: 16),
          if (m == 'onay_bekliyor') ...[
            _birincil('Onayla ve yayınla', () => Navigator.of(c).pop('onayla')),
            const SizedBox(height: 10),
            _ikincil('Reddet', () => Navigator.of(c).pop('kaldir'), ikon: Icons.close_rounded, renk: Renk.kiremit),
          ] else if (i.aktif) ...[
            _ikincil('Yayından gizle', () => Navigator.of(c).pop('gizle'), ikon: Icons.visibility_off_outlined, renk: Renk.kiremit),
            const SizedBox(height: 10),
            _ikincil('Kalıcı olarak kaldır', () => Navigator.of(c).pop('kaldir'), ikon: Icons.delete_outline_rounded, renk: Renk.kiremit),
          ] else if (m != null) ...[
            _birincil('Yeniden yayına al', () => Navigator.of(c).pop('yayina_al'), ikon: Icons.replay_rounded),
            if (m != 'yonetici_kaldirdi') ...[
              const SizedBox(height: 10),
              _ikincil('Kalıcı olarak kaldır', () => Navigator.of(c).pop('kaldir'), ikon: Icons.delete_outline_rounded, renk: Renk.kiremit),
            ],
          ] else
            const Text('Bu ilanı satıcı kendisi yayından kaldırmış veya satılmış; yönetici işlemi gerekmiyor.', style: TextStyle(color: Renk.soluk)),
          const SizedBox(height: 10),
          _ikincil('Satıcının profili', () => Navigator.of(c).pop('satici'), ikon: Icons.person_outline_rounded),
          if (i.aktif) ...[
            const SizedBox(height: 10),
            _ikincil('İlan sayfasını aç', () => Navigator.of(c).pop('ac'), ikon: Icons.open_in_new_rounded),
          ],
        ]),
      ),
    ),
  );
  if (sonuc == null || !context.mounted) return false;
  switch (sonuc) {
    case 'satici':
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => KullaniciScreen(id: i.saticiId)));
      return true;
    case 'ac':
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailScreen(ilan: i)));
      return false;
    case 'onayla':
      return _yap(context, () => yonetim.ilanIslem(i.id, 'onayla'), 'İlan onaylandı ve yayına çıktı');
    case 'yayina_al':
      return _yap(context, () => yonetim.ilanIslem(i.id, 'yayina_al'), 'İlan yeniden yayında; şikâyetleri kapatıldı');
    default:
      final neden = await nedenSor(context, sonuc == 'gizle' ? 'Neden gizleniyor?' : (m == 'onay_bekliyor' ? 'Neden reddediliyor?' : 'Neden kaldırılıyor?'),
          ilanGerekceleri,
          dugme: sonuc == 'gizle' ? 'Yayından gizle' : (m == 'onay_bekliyor' ? 'Reddet' : 'Kalıcı olarak kaldır'));
      if (neden == null || !context.mounted) return false;
      return _yap(context, () => yonetim.ilanIslem(i.id, sonuc, neden: neden), sonuc == 'gizle' ? 'İlan gizlendi, satıcıya bildirildi' : 'İlan kaldırıldı, satıcıya bildirildi');
  }
}

/// Paneldeki ilan satırı
class YIlanKarti extends StatelessWidget {
  const YIlanKarti(this.y, {super.key, required this.onTap});
  final YIlan y;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final i = y.ilan;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        button: true,
        label: '${i.cins}, ${i.durumAd}${y.nedenler.isEmpty ? '' : ', şüpheli: ${y.nedenler.join(', ')}'}',
        child: Basma(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: kutu(18),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(width: 76, child: FotoKutusu(url: y.foto, yukseklik: 76, yaricap: 12)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(i.cins, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text('${i.turAd} · ${i.adet} baş · ${i.yer}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Renk.soluk, fontSize: 13)),
                    Text('${tl(i.toplam)} · ${sayi(i.kgFiyat)} ₺/kg', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    Text('${i.saticiAd}${y.saticiAskida ? ' · askıda' : ''} · ${goreli(i.olusturma)}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Renk.soluk, fontSize: 13)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      Etiket(i.durumAd, uyari: i.moderasyon != null),
                      for (final n in y.nedenler) Etiket(n, uyari: true, ikon: Icons.warning_amber_rounded),
                      if (y.sikayet > 0) Etiket('${y.sikayet} şikâyet', uyari: true, ikon: Icons.flag_outlined),
                    ]),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ======================= İLAN LİSTELERİ =======================

class YoneticiIlanlarScreen extends StatefulWidget {
  const YoneticiIlanlarScreen({super.key, required this.filtre, required this.baslikYazi, this.aciklama});
  final String filtre, baslikYazi;
  final String? aciklama;
  @override
  State<YoneticiIlanlarScreen> createState() => _YoneticiIlanlarScreenState();
}

class _YoneticiIlanlarScreenState extends State<YoneticiIlanlarScreen> {
  final _ara = TextEditingController();
  late Future<List<YIlan>> _f = _getir();
  Future<List<YIlan>> _getir() => yonetim.ilanlar(widget.filtre, ara: _ara.text.trim());
  void _yenile() => setState(() => _f = _getir());

  @override
  Widget build(BuildContext context) {
    final arama = widget.filtre == 'tumu';
    return Scaffold(
      appBar: AppBar(title: Text(widget.baslikYazi)),
      body: Column(children: [
        if (arama)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _ara,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _yenile(),
              decoration: InputDecoration(
                hintText: 'Cins, il veya satıcı adı',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(tooltip: 'Ara', icon: const Icon(Icons.arrow_forward_rounded), onPressed: _yenile),
              ),
            ),
          ),
        if (widget.aciklama != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(widget.aciklama!, style: const TextStyle(color: Renk.soluk, fontSize: 13)),
          ),
        Expanded(
          child: FutureBuilder<List<YIlan>>(
            future: _f,
            builder: (context, s) {
              if (s.connectionState != ConnectionState.done) return yukleniyor();
              if (s.hasError) return HataKutusu(s.error!, tekrar: _yenile);
              final l = s.data!;
              if (l.isEmpty) return const Bos('Liste boş', 'Şu an burada bekleyen ilan yok.');
              return RefreshIndicator(
                color: Renk.yesil,
                onRefresh: () async => _yenile(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    for (final y in l)
                      YIlanKarti(y, onTap: () async {
                        if (await ilanIslemSayfasi(context, y)) _yenile();
                      }),
                  ],
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ======================= ŞİKÂYETLER =======================

class SikayetlerScreen extends StatefulWidget {
  const SikayetlerScreen({super.key});
  @override
  State<SikayetlerScreen> createState() => _SikayetlerScreenState();
}

class _SikayetlerScreenState extends State<SikayetlerScreen> {
  static const _durumlar = {'yeni': 'Yeni', 'inceleniyor': 'İnceleniyor', 'kapandi': 'Kapandı'};
  String _durum = 'yeni';
  late Future<List<YSikayet>> _f = yonetim.sikayetler(_durum);
  void _yenile() => setState(() => _f = yonetim.sikayetler(_durum));

  Future<void> _durumDegistir(YSikayet s, String d, String mesaj) async {
    if (await _yap(context, () => yonetim.sikayetDurum(s.id, d), mesaj)) _yenile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Şikâyetler')),
      body: Column(children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(children: [
            for (final e in _durumlar.entries)
              Cip(e.value, _durum == e.key, () {
                _durum = e.key;
                _yenile();
              }),
          ]),
        ),
        Expanded(
          child: FutureBuilder<List<YSikayet>>(
            future: _f,
            builder: (context, s) {
              if (s.connectionState != ConnectionState.done) return yukleniyor();
              if (s.hasError) return HataKutusu(s.error!, tekrar: _yenile);
              final l = s.data!;
              if (l.isEmpty) return Bos('Şikâyet yok', '"${_durumlar[_durum]}" listesinde şikâyet bulunmuyor.');
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [for (final x in l) _sikayetKarti(x)],
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _sikayetKarti(YSikayet s) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: kutu(18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.flag_outlined, color: Renk.kiremit, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(s.sebepAd, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            Text(goreli(s.tarih), style: const TextStyle(color: Renk.soluk, fontSize: 13)),
          ]),
          const SizedBox(height: 4),
          Text('Bildiren: ${s.bildiren ?? 'bilinmiyor'}', style: const TextStyle(color: Renk.soluk, fontSize: 13)),
          if (s.detay != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Renk.zemin2, borderRadius: BorderRadius.circular(12)),
              child: Text('“${s.detay}”', style: const TextStyle(height: 1.4)),
            ),
          ],
          if (s.ilan != null) ...[
            const SizedBox(height: 10),
            if (s.ayniIlan > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('Bu ilanı ${s.ayniIlan} farklı kişi şikâyet etti', style: const TextStyle(color: Renk.kiremit, fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            YIlanKarti(s.ilan!, onTap: () async {
              if (await ilanIslemSayfasi(context, s.ilan!)) _yenile();
            }),
          ] else if (s.kullaniciId != null) ...[
            const SizedBox(height: 10),
            _ikincil('Şikâyet edilen: ${s.kullaniciAd ?? 'kullanıcı'}', () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => KullaniciScreen(id: s.kullaniciId!)));
              _yenile();
            }, ikon: Icons.person_outline_rounded),
          ],
          const SizedBox(height: 10),
          Row(children: [
            if (s.durum == 'yeni') ...[
              Expanded(child: _ikincil('İncelemeye al', () => _durumDegistir(s, 'inceleniyor', 'İncelemeye alındı'), ikon: Icons.hourglass_top_rounded)),
              const SizedBox(width: 10),
            ],
            if (s.durum != 'kapandi')
              Expanded(child: _ikincil('Kapat', () => _durumDegistir(s, 'kapandi', 'Şikâyet kapatıldı'), ikon: Icons.check_rounded))
            else
              Expanded(child: _ikincil('Yeniden aç', () => _durumDegistir(s, 'yeni', 'Şikâyet yeniden açıldı'), ikon: Icons.undo_rounded)),
          ]),
        ]),
      ),
    );
  }
}

// ======================= KULLANICILAR =======================

class KullanicilarScreen extends StatefulWidget {
  const KullanicilarScreen({super.key, this.sadeceAskida = false});
  final bool sadeceAskida;
  @override
  State<KullanicilarScreen> createState() => _KullanicilarScreenState();
}

class _KullanicilarScreenState extends State<KullanicilarScreen> {
  final _ara = TextEditingController();
  late bool _askida = widget.sadeceAskida;
  late Future<List<YKullanici>> _f = _getir();
  Future<List<YKullanici>> _getir() => yonetim.kullanicilar(ara: _ara.text.trim(), sadeceAskida: _askida);
  void _yenile() => setState(() => _f = _getir());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kullanıcılar')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: TextField(
            controller: _ara,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _yenile(),
            decoration: InputDecoration(
              hintText: 'Ad veya telefon',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(tooltip: 'Ara', icon: const Icon(Icons.arrow_forward_rounded), onPressed: _yenile),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(children: [
            Cip('Hepsi', !_askida, () {
              _askida = false;
              _yenile();
            }),
            Cip('Askıdakiler', _askida, () {
              _askida = true;
              _yenile();
            }),
          ]),
        ),
        Expanded(
          child: FutureBuilder<List<YKullanici>>(
            future: _f,
            builder: (context, s) {
              if (s.connectionState != ConnectionState.done) return yukleniyor();
              if (s.hasError) return HataKutusu(s.error!, tekrar: _yenile);
              final l = s.data!;
              if (l.isEmpty) return const Bos('Kimse bulunamadı', 'Adın bir kısmını veya telefonun son 4 hanesini yazmayı dene.');
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  for (final k in l)
                    _KullaniciSatiri(k, onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => KullaniciScreen(id: k.id)));
                      _yenile();
                    }),
                ],
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _KullaniciSatiri extends StatelessWidget {
  const _KullaniciSatiri(this.k, {required this.onTap});
  final YKullanici k;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Semantics(
          button: true,
          label: '${k.ad}${k.askida ? ', askıda' : ''}',
          child: Basma(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: kutu(18),
                child: Row(children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: k.askida ? _uyariZemin : Renk.okZemin,
                    child: Text(k.ad.isEmpty ? '?' : k.ad.substring(0, 1).toUpperCase(),
                        style: TextStyle(fontWeight: FontWeight.w800, color: k.askida ? Renk.kiremit : Renk.okYazi)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(k.ad, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Text('${k.ilce}, ${k.il} · ${k.rolAd}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Renk.soluk, fontSize: 13)),
                      Text(telefonYaz(k.telefon), style: const TextStyle(color: Renk.soluk, fontSize: 13)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        if (k.askida) const Etiket('Askıda', uyari: true, ikon: Icons.block_rounded),
                        if (k.yonetici) const Etiket('Yönetici'),
                        if (k.ornek) const Etiket('Örnek hesap'),
                        Etiket('${k.ilanAktif} aktif ilan'),
                        if (k.sikayet > 0) Etiket('${k.sikayet} şikâyet', uyari: true, ikon: Icons.flag_outlined),
                      ]),
                    ]),
                  ),
                  const Icon(Icons.chevron_right, color: Renk.soluk),
                ]),
              ),
            ),
          ),
        ),
      );
}

class KullaniciScreen extends StatefulWidget {
  const KullaniciScreen({super.key, required this.id});
  final String id;
  @override
  State<KullaniciScreen> createState() => _KullaniciScreenState();
}

class _KullaniciScreenState extends State<KullaniciScreen> {
  late Future<YKullanici> _f = yonetim.kullanici(widget.id);
  void _yenile() => setState(() => _f = yonetim.kullanici(widget.id));

  Future<void> _aski(YKullanici k) async {
    if (k.askida) {
      final ok = await onayIste(context, 'Askı kaldırılsın mı?', '${k.ad} tekrar ilan verebilir ve mesajlaşabilir. Askı yüzünden gizlenen ilanları yeniden yayına çıkar.',
          'Askıyı kaldır');
      if (!ok || !mounted) return;
      await _yap(context, () => yonetim.askiyaAl(k.id, false), 'Askı kaldırıldı');
    } else {
      final neden = await nedenSor(context, '${k.ad} askıya alınsın mı?', askiGerekceleri, dugme: 'Hesabı askıya al');
      if (neden == null || !mounted) return;
      await _yap(context, () => yonetim.askiyaAl(k.id, true, neden: neden), 'Hesap askıya alındı, ilanları gizlendi');
    }
    if (mounted) _yenile();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kullanıcı')),
      body: FutureBuilder<YKullanici>(
        future: _f,
        builder: (context, s) {
          if (s.connectionState != ConnectionState.done) return yukleniyor();
          if (s.hasError) return HataKutusu(s.error!, tekrar: _yenile);
          final k = s.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Row(children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: k.askida ? _uyariZemin : Renk.okZemin,
                  child: Text(k.ad.isEmpty ? '?' : k.ad.substring(0, 1).toUpperCase(),
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: k.askida ? Renk.kiremit : Renk.okYazi)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(k.ad, style: baslik(22)),
                    SelectableText(telefonYaz(k.telefon), style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text('${k.ilce}, ${k.il} · ${k.rolAd} · ${ayYil(k.kayit)} üyesi', style: const TextStyle(color: Renk.soluk, fontSize: 13)),
                    if (k.puanSayisi > 0)
                      Text('★ ${puanYaz(k.puan)} (${k.puanSayisi} değerlendirme)', style: const TextStyle(color: yildizRenk, fontWeight: FontWeight.w800, fontSize: 13)),
                  ]),
                ),
              ]),
              if (k.askida) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: _uyariZemin, borderRadius: BorderRadius.circular(14)),
                  child: Text('Hesap askıda${k.askidaNeden == null ? '' : ': ${k.askidaNeden}'}',
                      style: const TextStyle(color: Renk.kiremit, fontWeight: FontWeight.w800)),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                Etiket('${k.ilanAktif} aktif ilan'),
                Etiket('${k.ilanToplam} ilan toplam'),
                Etiket('${k.satildi} satıldı'),
                Etiket('${k.mesaj} mesaj'),
                Etiket('${k.talep} alıcı talebi'),
                Etiket('${k.sikayetToplam} şikâyet', uyari: k.sikayetToplam > 0, ikon: Icons.flag_outlined),
              ]),
              const SizedBox(height: 16),
              if (k.yonetici)
                const Text('Yöneticiler askıya alınamaz.', style: TextStyle(color: Renk.soluk))
              else if (k.askida)
                _birincil('Askıyı kaldır', () => _aski(k), ikon: Icons.lock_open_rounded)
              else
                _birincil('Hesabı askıya al', () => _aski(k), ikon: Icons.block_rounded, renk: Renk.kiremit),
              const SizedBox(height: 22),
              Text('Hakkındaki şikâyetler (${k.sikayetler.length})', style: baslik(18)),
              const SizedBox(height: 8),
              if (k.sikayetler.isEmpty) const Text('Şikâyet yok.', style: TextStyle(color: Renk.soluk)),
              for (final x in k.sikayetler)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: kutu(14, Golge.hafif),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(x.sebepAd, style: const TextStyle(fontWeight: FontWeight.w800))),
                      Etiket(const {'yeni': 'Yeni', 'inceleniyor': 'İnceleniyor', 'kapandi': 'Kapandı'}[x.durum] ?? x.durum, uyari: x.durum == 'yeni'),
                    ]),
                    Text('${x.bildiren ?? ''}${x.kullaniciAd == null ? '' : ' · ${x.kullaniciAd}'} · ${goreli(x.tarih)}',
                        style: const TextStyle(color: Renk.soluk, fontSize: 13)),
                    if ((x.detay ?? '').isNotEmpty) Text('“${x.detay}”', style: const TextStyle(height: 1.4)),
                  ]),
                ),
              const SizedBox(height: 18),
              Text('İlanları (${k.ilanlar.length})', style: baslik(18)),
              const SizedBox(height: 8),
              if (k.ilanlar.isEmpty) const Text('İlanı yok.', style: TextStyle(color: Renk.soluk)),
              for (final y in k.ilanlar)
                YIlanKarti(y, onTap: () async {
                  if (await ilanIslemSayfasi(context, y)) _yenile();
                }),
            ],
          );
        },
      ),
    );
  }
}
