import 'package:flutter/material.dart';

import '../data.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'chat_screen.dart';
import 'phone_screen.dart';

/// Tek bir alıcı talebinin kartı (saf bileşen, test edilebilir).
class TalepKarti extends StatelessWidget {
  const TalepKarti({super.key, required this.talep, this.benim = false, this.onOner, this.onKapat});
  final Talep talep;
  final bool benim;
  final VoidCallback? onOner;
  final VoidCallback? onKapat;

  @override
  Widget build(BuildContext context) {
    final t = talep;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Renk.cizgi)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(t.baslik, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
              Text(goreli(t.olusturma), style: const TextStyle(color: Renk.soluk, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Text('${t.adet} baş · ${t.il}${t.amacAd == null ? '' : ' · ${t.amacAd}'}', style: const TextStyle(color: Renk.soluk)),
          if (t.butce != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Bütçe: en fazla ${tl(t.butce!)}', style: const TextStyle(fontWeight: FontWeight.w800, color: Renk.kiremit))),
          if (t.aciklama != null && t.aciklama!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(t.aciklama!, style: const TextStyle(height: 1.4))),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text(benim ? 'Senin talebin${t.aktif ? '' : ' · kapandı'}' : t.aliciAd, style: const TextStyle(color: Renk.soluk, fontSize: 13))),
              if (benim && t.aktif) TextButton(onPressed: onKapat, child: const Text('Talebi kapat')),
              if (!benim) FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 16)), onPressed: onOner, child: const Text('İlanımı öner')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Talep verme akışını açar; yayınlanırsa ana sayfada talepler sekmesine geçer.
Future<void> talepVerGit(BuildContext context) async {
  if (!await girisGerekli(context)) return;
  if (!context.mounted) return;
  final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const TalepVerScreen()));
  if (ok == true) {
    app.anaSekme = 1;
    app.sekme = 0;
    app.ilanlariYenile();
  }
}

/// Talep listesi (gömülebilir, kaydırmaz): tür süzgeci, taleplerim, öner / kapat.
class TaleplerGovdesi extends StatefulWidget {
  const TaleplerGovdesi({super.key});

  @override
  State<TaleplerGovdesi> createState() => _TaleplerGovdesiState();
}

class _TaleplerGovdesiState extends State<TaleplerGovdesi> {
  String _tur = 'Hepsi';
  bool _benim = false;
  Future<List<Talep>>? _f;
  int _surum = -1;

  @override
  void initState() {
    super.initState();
    _surum = app.ilanSurum;
    app.addListener(_degisti);
    _f = talepler();
  }

  @override
  void dispose() {
    app.removeListener(_degisti);
    super.dispose();
  }

  void _degisti() {
    if (mounted && app.ilanSurum != _surum) {
      _surum = app.ilanSurum;
      _yukle();
    }
  }

  void _yukle() {
    setState(() {
      _f = _benim ? taleplerim() : talepler(tur: _tur == 'Hepsi' ? null : turKod[_tur]);
    });
  }

  Future<void> _oner(Talep t) async {
    if (!await girisGerekli(context)) return;
    if (!mounted) return;
    List<Ilan> benimkiler;
    try {
      benimkiler = (await benimIlanlarim()).where((i) => i.aktif).toList();
    } catch (e) {
      if (mounted) bildir(context, 'İlanların alınamadı: $e');
      return;
    }
    if (!mounted) return;
    if (benimkiler.isEmpty) {
      bildir(context, 'Önerebilmek için yayında bir ilanın olmalı.');
      return;
    }
    final secilen = await showModalBottomSheet<Ilan>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            Text('Hangi ilanını önerelim?', style: baslik(20)),
            const SizedBox(height: 8),
            for (final i in benimkiler)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${i.cins} · ${i.adet} baş', style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text('${tl(i.toplam)} · ${i.yer}'),
                onTap: () => Navigator.pop(ctx, i),
              ),
          ],
        ),
      ),
    );
    if (secilen == null) return;
    try {
      final k = await talebeIlanOner(t.id, secilen.id);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(konusmaId: k)));
    } catch (e) {
      if (mounted) bildir(context, 'Öneri gönderilemedi: $e');
    }
  }

  Future<void> _kapat(Talep t) async {
    final ok = await onayIste(context, 'Talebi kapatmak istiyor musun?', 'Talep listeden kalkar.', 'Kapat');
    if (!ok) return;
    try {
      await talepKapat(t.id);
      _yukle();
    } catch (e) {
      if (mounted) bildir(context, 'Kapatılamadı: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Alıcılar aradıklarını yayınlar, satıcılar uygun ilanlarını önerir.', style: TextStyle(color: Renk.soluk, height: 1.4)),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final t in ['Hepsi', ...turSecenekleri])
                Cip(t, !_benim && _tur == t, () {
                  _benim = false;
                  _tur = t;
                  _yukle();
                }),
              Cip('Taleplerim', _benim, () {
                if (db.auth.currentSession == null) {
                  girisGerekli(context);
                  return;
                }
                _benim = true;
                _yukle();
              }),
            ],
          ),
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<Talep>>(
          future: _f,
          builder: (context, s) {
            if (s.connectionState != ConnectionState.done) return yukleniyor();
            if (s.hasError) return HataKutusu(s.error!, tekrar: _yukle);
            final l = s.data!;
            if (l.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(child: Text(_benim ? 'Henüz talebin yok.' : 'Şu an açık talep yok.', style: const TextStyle(color: Renk.soluk))),
              );
            }
            return Column(
              children: [
                for (final t in l) TalepKarti(talep: t, benim: t.aliciId == uid, onOner: () => _oner(t), onKapat: () => _kapat(t)),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Bildirimden açılan tam sayfa görünüm.
class TaleplerScreen extends StatelessWidget {
  const TaleplerScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Alıcı talepleri')),
        bottomNavigationBar: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: SafeArea(top: false, child: FilledButton(onPressed: () => talepVerGit(context), child: const Text('Talep yayınla'))),
        ),
        body: ListView(padding: const EdgeInsets.all(16), children: const [TaleplerGovdesi()]),
      );
}

class TalepVerScreen extends StatefulWidget {
  const TalepVerScreen({super.key});

  @override
  State<TalepVerScreen> createState() => _TalepVerScreenState();
}

class _TalepVerScreenState extends State<TalepVerScreen> {
  String _tur = 'Küçükbaş';
  String? _cins;
  String? _amac;
  int _adet = 1;
  final _butce = TextEditingController();
  late final TextEditingController _il = TextEditingController(text: app.profil?['il'] as String? ?? '');
  final _acik = TextEditingController();
  bool _yuk = false;
  String? _hata;

  Future<void> _yayinla() async {
    final b = sayiOku(_butce.text);
    if (_il.text.trim().isEmpty) {
      setState(() => _hata = 'Hangi ilde aradığını yaz.');
      return;
    }
    if (_butce.text.trim().isNotEmpty && (b == null || b <= 0)) {
      setState(() => _hata = 'Bütçeyi sayı olarak gir.');
      return;
    }
    setState(() {
      _hata = null;
      _yuk = true;
    });
    try {
      await talepVer({
        'buyer_id': uid,
        'tur': turKod[_tur],
        'cins': _cins,
        'adet': _adet,
        'amac': _amac,
        'butce_max': b,
        'il': _il.text.trim(),
        'aciklama': _acik.text.trim().isEmpty ? null : _acik.text.trim(),
      });
      if (!mounted) return;
      bildir(context, 'Talebin yayınlandı, uygun satıcılara haber verildi');
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _hata = 'Talep yayınlanamadı: $e\n(006_talepler.sql çalıştırıldı mı?)');
    } finally {
      if (mounted) setState(() => _yuk = false);
    }
  }

  Widget _et(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)));

  @override
  Widget build(BuildContext context) {
    final cinsler = cinsListesi[_tur] ?? [];
    return Scaffold(
      appBar: AppBar(title: const Text('Talep yayınla')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _et('Ne arıyorsun?'),
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
          _et('Cins (isteğe bağlı)'),
          DropdownButtonFormField<String>(
            value: _cins,
            isExpanded: true,
            hint: const Text('Fark etmez'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Fark etmez')),
              for (final c in cinsler) DropdownMenuItem(value: c, child: Text(c)),
            ],
            onChanged: (v) => setState(() => _cins = v),
          ),
          const SizedBox(height: 14),
          _et('Kaç baş?'),
          Container(
            height: 56,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Renk.cizgi)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(tooltip: 'Azalt', onPressed: () => setState(() => _adet = (_adet - 1).clamp(1, 1000)), icon: const Icon(Icons.remove)),
                Text('$_adet', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                IconButton(tooltip: 'Artır', onPressed: () => setState(() => _adet = (_adet + 1).clamp(1, 1000)), icon: const Icon(Icons.add)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _et('Amaç (isteğe bağlı)'),
          Wrap(runSpacing: 8, children: [
            for (final e in amacEtiket.entries) Cip(e.value, _amac == e.key, () => setState(() => _amac = _amac == e.key ? null : e.key)),
          ]),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: TextField(controller: _il, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'İl'))),
              const SizedBox(width: 12),
              Expanded(child: TextField(controller: _butce, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'En fazla bütçe (₺)'))),
            ],
          ),
          const SizedBox(height: 14),
          TextField(controller: _acik, maxLines: 3, maxLength: 1000, decoration: const InputDecoration(labelText: 'Not (isteğe bağlı)', alignLabelWithHint: true)),
          if (_hata != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_hata!, style: const TextStyle(color: uyariRenk, fontWeight: FontWeight.w700))),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _yuk ? null : _yayinla,
            child: _yuk ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Talebi yayınla'),
          ),
        ],
      ),
    );
  }
}
