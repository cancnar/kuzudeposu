import 'dart:async';

import 'package:flutter/material.dart';

import '../data.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'phone_screen.dart';

class FilterScreen extends StatefulWidget {
  const FilterScreen({super.key});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen> {
  late Filtre _f = app.filtre.kopya();
  int? _sayi;
  Timer? _t;
  int _anahtar = 0;

  @override
  void initState() {
    super.initState();
    _say();
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _planla() {
    _t?.cancel();
    _t = Timer(const Duration(milliseconds: 400), _say);
  }

  Future<void> _say() async {
    final bu = _f.imza;
    try {
      final l = await ilanAra(app.arama, _f);
      if (mounted && bu == _f.imza) setState(() => _sayi = l.length);
    } catch (_) {
      if (mounted) setState(() => _sayi = null);
    }
  }

  void _sec(String k, String v) {
    setState(() => _f[k] = v);
    _planla();
  }

  Widget _grup(String baslikYazi, Widget cocuk) => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Renk.cizgi))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(baslikYazi, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 10),
            cocuk,
          ],
        ),
      );

  Widget _cipler(String k, List<String> secenekler) => Wrap(
        runSpacing: 8,
        children: [for (final s in secenekler) Cip(s, _f[k] == s, () => _sec(k, s))],
      );

  Widget _aralik(String ad, String a, String b, String birim) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ad, style: const TextStyle(color: Renk.soluk, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: ValueKey('$a$_anahtar'),
                    initialValue: _f[a],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'En az'),
                    onChanged: (v) {
                      _f[a] = v;
                      _planla();
                    },
                  ),
                ),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('–')),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('$b$_anahtar'),
                    initialValue: _f[b],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'En çok'),
                    onChanged: (v) {
                      _f[b] = v;
                      _planla();
                    },
                  ),
                ),
                SizedBox(width: 38, child: Text(' $birim', style: const TextStyle(color: Renk.soluk))),
              ],
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
        title: const Text('Filtrele'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _f.hepsiniTemizle();
                _anahtar++;
              });
              _planla();
            },
            child: const Text('Temizle'),
          ),
        ],
      ),
      body: ListView(
        children: [
          _grup('Hayvan türü', _cipler('tur', ['Hepsi', ...turSecenekleri])),
          _grup(
            'Cins',
            TextFormField(
              key: ValueKey('cins$_anahtar'),
              initialValue: _f['cins'],
              decoration: const InputDecoration(hintText: 'Örn. Simental'),
              onChanged: (v) {
                _f['cins'] = v;
                _planla();
              },
            ),
          ),
          _grup(
            'Satış şekli',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cipler('satis', ['Hepsi', 'Tek hayvan', 'Sürü']),
                const SizedBox(height: 12),
                _aralik('Hayvan adedi', 'adetMin', 'adetMax', 'baş'),
              ],
            ),
          ),
          _grup('Yaş ve ağırlık', Column(children: [_aralik('Yaş', 'yasMin', 'yasMax', 'ay'), _aralik('Ağırlık (sürüde ortalama)', 'kgMin', 'kgMax', 'kg')])),
          _grup('Fiyat', _aralik('Toplam fiyat', 'fiyatMin', 'fiyatMax', '₺')),
          _grup(
            'Konum',
            TextFormField(
              key: ValueKey('il$_anahtar'),
              initialValue: _f['il'],
              decoration: const InputDecoration(hintText: 'İl veya ilçe'),
              onChanged: (v) {
                _f['il'] = v;
                _planla();
              },
            ),
          ),
          _grup('Satış amacı', _cipler('amac', ['Hepsi', ...amacEtiket.values])),
          _grup(
            'Belgeler',
            Wrap(runSpacing: 8, children: [
              for (final e in belgeEtiket.entries)
                Cip(e.value, _f.belgeSecili.contains(e.key), () {
                  setState(() => _f.belgeDegistir(e.key));
                  _planla();
                }),
            ]),
          ),
          _grup('Sıralama', _cipler('sirala', Filtre.siralamalar)),
          const SizedBox(height: 120),
        ],
      ),
      bottomSheet: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                onPressed: () async {
                  if (!await girisGerekli(context)) return;
                  final baslikYazi = (_f['cins'].isNotEmpty ? _f['cins'] : (_f['tur'] != 'Hepsi' ? _f['tur'] : 'Tüm ilanlar')) + (_f['il'].isNotEmpty ? ' · ${_f['il']}' : '');
                  try {
                    await aramaKaydet(baslikYazi, _f);
                    if (context.mounted) bildir(context, 'Arama kaydedildi');
                  } catch (e) {
                    if (context.mounted) bildir(context, 'Kaydedilemedi: $e');
                  }
                },
                child: const Text('Bu aramayı kaydet'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () {
                  app.filtre = _f;
                  app.yenile();
                  Navigator.of(context).pop();
                },
                child: Text(_sayi == null ? 'İlanları göster' : '$_sayi ilanı göster'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
