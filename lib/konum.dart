import 'package:flutter/material.dart';

import 'iller.dart';
import 'theme.dart';
import 'widgets.dart';

export 'iller.dart';

/// Türkçe harf duyarsız karşılaştırma için: "KIVIRCIK", "kıvırcık", "kivircik" -> "kivircik".
/// Veri tabanındaki public.tr_norm() ile aynı kural.
String trNorm(String s) {
  const buyuk = 'ÇĞİIÖŞÜÂÎÛ';
  const kucuk = 'çğiıöşüâîû';
  final b = StringBuffer();
  for (final r in s.runes) {
    var c = String.fromCharCode(r);
    final i = buyuk.indexOf(c);
    if (i >= 0) c = kucuk[i];
    b.write(c.toLowerCase());
  }
  const harf = 'çğıöşüâîû';
  const ascii = 'cgiosuaiu';
  final t = b.toString().split('').map((c) {
    final i = harf.indexOf(c);
    return i >= 0 ? ascii[i] : c;
  }).join();
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
}

Il? ilBul(String? ad) {
  if (ad == null || ad.trim().isEmpty) return null;
  final n = trNorm(ad);
  for (final i in iller) {
    if (trNorm(i.ad) == n) return i;
  }
  return null;
}

Ilce? ilceBul(String? il, String? ilce) {
  final i = ilBul(il);
  if (i == null || ilce == null || ilce.trim().isEmpty) return null;
  final n = trNorm(ilce);
  for (final x in i.ilceler) {
    if (trNorm(x.ad) == n) return x;
  }
  return null;
}

/// İlçe biliniyorsa ilçe merkezi, yoksa il merkezi.
({double lat, double lng})? konumu(String? il, [String? ilce]) {
  final x = ilceBul(il, ilce);
  if (x != null) return (lat: x.lat, lng: x.lng);
  final i = ilBul(il);
  return i == null ? null : (lat: i.lat, lng: i.lng);
}

/// "Salihli, Manisa" / "Manisa" -> (il, ilçe). Filtrede saklanan metni çözer.
({String il, String? ilce})? konumCoz(String metin) {
  final p = metin.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  if (p.isEmpty) return null;
  if (p.length >= 2) {
    final i = ilBul(p.last);
    if (i != null) return (il: i.ad, ilce: ilceBul(i.ad, p.first)?.ad);
  }
  final i = ilBul(p.first);
  return i == null ? null : (il: i.ad, ilce: null);
}

String konumYaz(String il, String? ilce) => ilce == null || ilce.isEmpty ? il : '$ilce, $il';

/// İl ve (isteğe bağlı) ilçe seçtiren alt sayfa. Aramada Türkçe harf aranmaz ("izmir" = "İzmir").
/// [ilceZorunlu] false ise "Tüm il" seçeneği çıkar; [ilceSor] false ise sadece il seçilir.
Future<({String il, String? ilce})?> konumSec(BuildContext context, {String? il, bool ilceZorunlu = true, bool ilceSor = true}) {
  Il? secili = ilceSor ? ilBul(il) : null;
  final ara = TextEditingController();
  return showModalBottomSheet<({String il, String? ilce})>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Renk.krem,
    sheetAnimationStyle: Hareket.altSayfa(context),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (c) => StatefulBuilder(builder: (c, yenile) {
      final q = trNorm(ara.text);
      final Il? s = secili;
      final ogeler = s == null
          ? iller.where((i) => q.isEmpty || trNorm(i.ad).contains(q) || '${i.plaka}' == q).toList()
          : s.ilceler.where((x) => q.isEmpty || trNorm(x.ad).contains(q)).toList();
      return SizedBox(
        height: MediaQuery.of(c).size.height * .86,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 16, 4),
            child: Row(children: [
              if (s != null)
                IconButton(
                  tooltip: 'İllere dön',
                  onPressed: () => yenile(() {
                    secili = null;
                    ara.clear();
                  }),
                  icon: const Icon(Icons.arrow_back_rounded),
                )
              else
                const SizedBox(width: 12),
              Expanded(child: Text(s == null ? 'İl seç' : '${s.ad} · ilçe seç', style: baslik(22))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: ara,
              autofocus: false,
              onChanged: (_) => yenile(() {}),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: s == null ? 'İl ara (örn. Manisa)' : 'İlçe ara (örn. ${s.ilceler.first.ad})',
                labelText: s == null ? 'İl ara' : 'İlçe ara',
                prefixIcon: const Icon(Icons.search_rounded),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                if (s != null && !ilceZorunlu && q.isEmpty)
                  _KonumSatiri('Tüm ${s.ad}', vurgu: true, onTap: () => Navigator.pop(c, (il: s.ad, ilce: null))),
                for (final o in ogeler)
                  if (o is Il)
                    _KonumSatiri(o.ad, alt: '${o.plaka}', onTap: () {
                      if (!ilceSor) {
                        Navigator.pop(c, (il: o.ad, ilce: null));
                      } else {
                        yenile(() {
                          secili = o;
                          ara.clear();
                        });
                      }
                    })
                  else if (o is Ilce && s != null)
                    _KonumSatiri(o.ad, onTap: () => Navigator.pop(c, (il: s.ad, ilce: o.ad))),
                if (ogeler.isEmpty)
                  const Padding(padding: EdgeInsets.all(24), child: Text('Bulunamadı. Yazımı kontrol et.', textAlign: TextAlign.center, style: TextStyle(color: Renk.soluk))),
              ],
            ),
          ),
        ]),
      );
    }),
  );
}

class _KonumSatiri extends StatelessWidget {
  const _KonumSatiri(this.ad, {required this.onTap, this.alt, this.vurgu = false});
  final String ad;
  final String? alt;
  final bool vurgu;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: ad,
        excludeSemantics: true,
        onTap: onTap,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 50),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Renk.ayrac))),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(children: [
              Expanded(child: Text(ad, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: vurgu ? Renk.yesil : Renk.murekkep))),
              if (alt != null) Text(alt!, style: const TextStyle(color: Renk.soluk)),
              const Icon(Icons.chevron_right, color: Renk.soluk),
            ]),
          ),
        ),
      );
}

/// Form alanı gibi görünen, dokununca [konumSec] açan kutu.
class KonumAlani extends StatelessWidget {
  const KonumAlani({super.key, required this.il, this.ilce, required this.secildi, this.hata, this.etiket = 'İl ve ilçe', this.ilceZorunlu = true, this.ilceSor = true});
  final String? il, ilce;
  final void Function(String il, String? ilce) secildi;
  final String? hata;
  final String etiket;
  final bool ilceZorunlu, ilceSor;

  @override
  Widget build(BuildContext context) {
    final dolu = il != null && il!.isNotEmpty;
    Future<void> ac() async {
      final s = await konumSec(context, il: il, ilceZorunlu: ilceZorunlu, ilceSor: ilceSor);
      if (s != null) secildi(s.il, s.ilce);
    }

    return Semantics(
      button: true,
      label: etiket,
      value: dolu ? konumYaz(il!, ilce) : null,
      excludeSemantics: true,
      onTap: ac,
      child: GestureDetector(
        onTap: ac,
        child: InputDecorator(
          isEmpty: !dolu,
          decoration: InputDecoration(
            labelText: etiket,
            errorText: hata,
            prefixIcon: const Icon(Icons.place_outlined),
            suffixIcon: const Icon(Icons.expand_more_rounded),
          ),
          child: Text(dolu ? konumYaz(il!, ilce) : '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}
