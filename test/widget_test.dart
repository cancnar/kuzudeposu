import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuzu_deposu/galeri.dart';
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
  galeriTestleri();
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

Future<ui.Image> _buyukResim(int g, int y) async {
  final k = ui.PictureRecorder();
  final c = Canvas(k);
  c.drawRect(Rect.fromLTWH(0, 0, g.toDouble(), y.toDouble()), Paint()..color = const Color(0xFF2F5D3A));
  c.drawCircle(Offset(g / 2, y / 2), g / 4, Paint()..color = Colors.white);
  return k.endRecording().toImage(g, y);
}

void galeriTestleri() {
  testWidgets('galeri: telefona oranlı, alttaki bilgiler görünür, kaydırılır, tam ekran açılır', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    // Büyük (3000x4000, dikey) bir fotoğraf: eskiden ekranı kaplıyordu.
    final img = (await t.runAsync(() async {
      final i = await _buyukResim(3000, 4000);
      final b = await i.toByteData(format: ui.ImageByteFormat.png);
      return b!.buffer.asUint8List();
    }))!;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(children: [
          FotoGaleri(fotolar: const ['a', 'b', 'c'], saglayici: (_) => MemoryImage(img)),
          const Padding(padding: EdgeInsets.all(16), child: Text('SATICI BILGISI')),
        ]),
      ),
    ));
    await t.pump();
    final boyut = t.getSize(find.byType(AspectRatio).first);
    expect(boyut.width, 390);
    expect(boyut.height, closeTo(292.5, 0.5), reason: '4:3 oranı bozuk');
    expect(find.text('SATICI BILGISI').hitTestable(), findsOneWidget, reason: 'alt bilgiler ekranda görünmüyor');
    expect(find.text('1/3'), findsOneWidget);
    await t.drag(find.byType(PageView).first, const Offset(-300, 0));
    await t.pumpAndSettle();
    expect(find.text('2/3'), findsOneWidget, reason: 'kaydırınca sonraki fotoğrafa geçmedi');
    await t.tap(find.byTooltip('Sonraki fotoğraf'));
    await t.pumpAndSettle();
    expect(find.text('3/3'), findsOneWidget, reason: 'ok düğmesi çalışmıyor');
    await t.tap(find.byType(Image).first);
    await t.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsWidgets, reason: 'tam ekran görüntüleyici açılmadı');
    await t.tap(find.byTooltip('Kapat'));
    await t.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(t.takeException(), isNull);
  });
}
