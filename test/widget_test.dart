import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuzu_deposu/galeri.dart';
import 'package:kuzu_deposu/models.dart';
import 'package:kuzu_deposu/rehber.dart';
import 'package:kuzu_deposu/screens/satici_screen.dart';
import 'package:kuzu_deposu/screens/talepler_screen.dart';
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

Object? tester_exception(WidgetTester t) => t.takeException();

void main() {
  galeriTestleri();
  saticiTestleri();
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

  test('amaç ve belge filtresi + ilan alanları', () {
    final f = Filtre({'amac': 'Kurbanlık'});
    f.belgeDegistir('kupe');
    f.belgeDegistir('saglik_raporu');
    final p = f.rpc('');
    expect(p['p_amac'], 'kurbanlik');
    expect(p['p_belgeler'], ['kupe', 'saglik_raporu']);
    expect(f.aktif().length, 2);
    f.belgeDegistir('kupe');
    expect(f.belgeSecili, ['saglik_raporu']);
    f.sifirla(['amac', 'belgeler']);
    expect(f.rpc('').containsKey('p_amac'), false);
    expect(f.rpc('').containsKey('p_belgeler'), false);
    final i = Ilan.json({
      'id': 'a', 'seller_id': 's', 'tur': 'kucukbas', 'cins': 'Akkaraman', 'cinsiyet': 'erkek', 'adet': 1, 'yas_min': 8, 'yas_max': 8,
      'agirlik_kg': 50, 'toplam_fiyat': 20000, 'il': 'Manisa', 'ilce': 'Salihli', 'created_at': '2026-10-01T10:00:00Z',
      'amac': 'kurbanlik', 'belgeler': ['kupe', 'asi'], 'pazarlik': true, 'teslimat': 'ikisi', 'goruntulenme': 42,
    });
    expect(i.amacAd, 'Kurbanlık');
    expect(i.belgeler, ['kupe', 'asi']);
    expect(i.pazarlik, true);
    expect(i.teslimatAd, 'Yerinde veya nakliye');
    expect(i.goruntulenme, 42);
    expect(i.kalanGun, isNull);
    final j = Ilan.json({
      'id': 'b', 'seller_id': 's', 'tur': 'kucukbas', 'cins': 'X', 'cinsiyet': 'erkek', 'adet': 1, 'yas_min': 8, 'yas_max': 8,
      'agirlik_kg': 50, 'toplam_fiyat': 20000, 'il': 'a', 'ilce': 'b', 'created_at': '2026-10-01T10:00:00Z',
      'expires_at': DateTime.now().add(const Duration(days: 5, hours: 2)).toUtc().toIso8601String(),
    });
    expect(j.kalanGun, 5);
  });

  test('sevk belgeleri: il içi / iller arası', () {
    final b = ornek(); // büyükbaş, Manisa, belge yok
    expect(gerekliBelgeler(b, 'Manisa'), ['kupe', 'pasaport']);
    expect(gerekliBelgeler(b, 'manisa '), ['kupe', 'pasaport']);
    expect(gerekliBelgeler(b, 'İzmir'), ['kupe', 'pasaport', 'saglik_raporu']);
    expect(eksikBelgeler(b, null), ['kupe', 'pasaport']);
    expect(SaticiGuven(DateTime.now().subtract(const Duration(days: 3)), 0).yeni, true);
    expect(SaticiGuven(DateTime.now().subtract(const Duration(days: 3)), 2).yeni, false);
  });

  testWidgets('videolu ilan kartı rozet gösterir', (t) async {
    final i = Ilan.json({
      'id': 'v', 'seller_id': 's', 'tur': 'kucukbas', 'cins': 'Akkaraman', 'cinsiyet': 'erkek', 'adet': 1, 'yas_min': 8, 'yas_max': 8,
      'agirlik_kg': 50, 'toplam_fiyat': 20000, 'il': 'a', 'ilce': 'b', 'created_at': '2026-10-01T10:00:00Z', 'video_path': 'u/v/video.mp4',
    });
    expect(i.videoVar, true);
    expect(ornek().videoVar, false);
    await t.pumpWidget(MaterialApp(home: Scaffold(body: IlanKarti(ilan: i, onTap: () {}, favori: false, onFavori: () {}))));
    expect(find.text('Video'), findsOneWidget);
  });

  testWidgets('talep kartı çizilir, küçük ekranda taşmaz', (t) async {
    final talep = Talep.json({
      'id': 't', 'buyer_id': 'b', 'tur': 'kucukbas', 'cins': 'Akkaraman', 'adet': 12, 'amac': 'kurbanlik', 'butce_max': 150000,
      'il': 'Manisa', 'aciklama': 'Kurban bayramı için, küpeli olsun', 'created_at': '2026-10-30T10:00:00Z', 'buyer': {'full_name': 'Ali Veli'},
    });
    expect(talep.baslik, 'Akkaraman arıyorum');
    expect(talep.amacAd, 'Kurbanlık');
    for (final benim in [false, true]) {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      await t.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: TalepKarti(talep: talep, benim: benim)))));
      expect(find.text('Akkaraman arıyorum'), findsOneWidget);
      expect(find.text(benim ? 'Talebi kapat' : 'İlanımı öner'), findsOneWidget);
      expect(find.textContaining('150.000'), findsOneWidget);
    }
    addTearDown(t.view.reset);
  });

  testWidgets('alıcı rehberi çizilir ve açılır', (t) async {
    await t.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: AliciRehberi(ilan: ornek(), aliciIl: 'İzmir')))));
    expect(find.text('Satın almadan önce kontrol et'), findsOneWidget);
    await t.tap(find.text('Satın almadan önce kontrol et'));
    await t.pumpAndSettle();
    expect(find.textContaining('İller arası sevkte'), findsOneWidget);
    expect(tester_exception(t), isNull);
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

void saticiTestleri() {
  for (final olcek in [1.0, 1.3]) {
    testWidgets('satıcı başlığı 320 px ekranda taşmıyor (yazı ölçeği $olcek)', (t) async {
      t.view.physicalSize = const Size(320, 640);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: const Size(320, 640), textScaler: TextScaler.linear(olcek)),
          child: Scaffold(
            body: ListView(children: [
              SaticiBaslik(
                ad: 'Süleyman Aydın (örnek) uzun isim deneme',
                rol: 'Yetiştirici',
                yer: 'Eskil, Aksaray',
                uyelik: DateTime(2026, 10, 3),
                puan: 4.5,
                puanSayisi: 128,
                aktifSayi: 12,
                satisSayi: 4500,
                dagilim: const [1, 2, 3, 40, 82],
              ),
            ]),
          ),
        ),
      ));
      await t.pump();
      expect(t.takeException(), isNull);
      expect(find.text('Satış'), findsOneWidget);
      expect(find.textContaining('tarihinden beri üye'), findsOneWidget);
    });
  }
}
