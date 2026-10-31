import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuzu_deposu/models.dart';
import 'package:kuzu_deposu/theme.dart';
import 'package:kuzu_deposu/widgets.dart';

Ilan ornek({int adet = 1}) => Ilan(
      id: 'x',
      saticiId: 's',
      tur: 'buyukbas',
      cins: 'Simental düve çok uzun bir cins adı deneme',
      cinsiyet: 'disi',
      adet: adet,
      yasMin: 12,
      yasMax: adet > 1 ? 24 : 12,
      agirlik: 420,
      toplam: 1740000,
      satisSekli: 'birlikte',
      il: 'Manisa',
      ilce: 'Salihli',
      durum: 'aktif',
      olusturma: DateTime(2026, 10, 1),
      saticiAd: 'Mehmet Kaya',
      saticiPuan: 4.8,
      saticiPuanSayisi: 23,
    );

void main() {
  test('biçimlendirme yardımcıları', () {
    expect(tl(1740000), '1.740.000 ₺');
    expect(tl(999), '999 ₺');
    expect(puanYaz(4.8), '4,8');
    expect(maske('905321234567'), '+90 532 *** ** 67');
    expect(ornek().kgFiyat, (1740000 / 420).round());
    expect(ornek(adet: 12).yasMetni, '12–24 ay');
    expect(ornek().yasMetni, '12 ay');
  });

  test('filtre → rpc parametreleri', () {
    final f = Filtre({'tur': 'Küçükbaş', 'satis': 'Sürü', 'yasMin': '12', 'fiyatMax': '500000', 'sirala': 'Fiyat: azalan'});
    final p = f.rpc('kıvırcık');
    expect(p['p_tur'], 'kucukbas');
    expect(p['p_sale'], 'suru');
    expect(p['p_yas_min'], 12);
    expect(p['p_fiyat_max'], 500000);
    expect(p['p_sort'], 'fiyat_azalan');
    expect(p['p_q'], 'kıvırcık');
    expect(f.aktif().length, 3);
    f.sifirla(['satis']);
    expect(f['satis'], 'Hepsi');
  });

  testWidgets('ilan kartı küçük ekranda ve büyük yazıda taşmıyor', (t) async {
    for (final olcek in [1.0, 1.25]) {
      for (final adet in [1, 12]) {
        t.view.physicalSize = const Size(360, 740);
        t.view.devicePixelRatio = 1;
        await t.pumpWidget(MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: MediaQuery(
            data: MediaQueryData(size: const Size(360, 740), textScaler: TextScaler.linear(olcek)),
            child: Scaffold(body: ListView(children: [IlanKarti(ilan: ornek(adet: adet), onTap: () {}, favori: false, onFavori: () {})])),
          ),
        ));
        await t.pump();
        expect(t.takeException(), isNull, reason: 'taşma: ölçek $olcek adet $adet');
      }
    }
    addTearDown(t.view.reset);
  });

  testWidgets('ortak bileşenler çizilebiliyor', (t) async {
    await t.pumpWidget(MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: Scaffold(
        body: ListView(children: [
          const Logo(boyut: 80, ters: true),
          Bolum('Başlık', [Satir('Satır', deger: 'değer', onTap: () {}), AnahtarSatir('Anahtar', true, (_) {}, alt: 'alt')]),
          const Bos('Boş', 'açıklama', dugme: 'Tamam'),
          Wrap(children: [Cip('a', true, () {}), Cip('b', false, () {})]),
        ]),
      ),
    ));
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.text('Satır'), findsOneWidget);
  });
}
