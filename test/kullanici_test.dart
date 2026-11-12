// Kullanıcı testi bulguları (12 Kasım 2026): Türkçe arama, il/ilçe, makul değerler, mesafe, 4 adımlı ilan formu, yardım.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuzu_deposu/konum.dart';
import 'package:kuzu_deposu/models.dart';
import 'package:kuzu_deposu/screens/metinler_screen.dart';
import 'package:kuzu_deposu/screens/phone_screen.dart';
import 'package:kuzu_deposu/screens/sell_screen.dart';
import 'package:kuzu_deposu/theme.dart';

Future<void> ac(WidgetTester t, Widget ekran, {double genislik = 390, double yukseklik = 900, double olcek = 1}) async {
  t.view.physicalSize = ui.Size(genislik, yukseklik);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    theme: kuzuTema(),
    builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(olcek)), child: w!),
    home: ekran,
  ));
  await t.pumpAndSettle();
}

Future<void> dokun(WidgetTester t, Finder f) async {
  // Tembel listede henüz çizilmemiş öğeye kaydırarak ulaş.
  if (f.evaluate().isEmpty) await t.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  test('Türkçe harf duyarsız normalleştirme', () {
    expect(trNorm('KIVIRCIK'), 'kivircik');
    expect(trNorm('kıvırcık'), 'kivircik');
    expect(trNorm('kivircik'), 'kivircik');
    expect(trNorm('İZMİR  Karşıyaka'), 'izmir karsiyaka');
    expect(trNorm('Şarole ÇOĞUL Ğ'), 'sarole cogul g');
  });

  test('il/ilçe verisi: 81 il, 973 ilçe, bulma ve konum', () {
    expect(iller.length, 81);
    expect(iller.fold<int>(0, (t, i) => t + i.ilceler.length), 973);
    expect(ilBul('manisa')?.ad, 'Manisa');
    expect(ilBul('ISTANBUL')?.ad, 'İstanbul');
    expect(ilceBul('izmir', 'karsiyaka')?.ad, 'Karşıyaka');
    expect(ilceBul('Ağrı', 'doğubayazıt')?.ad, 'Doğubayazıt');
    final k = konumu('Manisa', 'Salihli')!;
    expect(k.lat, closeTo(38.48, .05));
    expect(k.lng, closeTo(28.13, .05));
    expect(konumCoz('Salihli, Manisa'), (il: 'Manisa', ilce: 'Salihli'));
    expect(konumCoz('manisa'), (il: 'Manisa', ilce: null));
    expect(konumYaz('Manisa', 'Salihli'), 'Salihli, Manisa');
  });

  test('makul değer denetimi', () {
    expect(agirlikMakul('buyukbas', 11), isNotNull);
    expect(agirlikMakul('buyukbas', 520), isNull);
    expect(agirlikMakul('kucukbas', 45), isNull);
    expect(fiyatMakul('buyukbas', 1, 300, 1111), contains('Kg fiyatı'));
    expect(fiyatMakul('buyukbas', 1, 520, 216000), isNull);
    expect(fiyatMakul('kucukbas', 30, 58, 680000), isNull);
    expect(fiyatMakul('kucukbas', 1, 4, 18000), isNotNull);
  });

  test('filtre: mesafe ve en yakın', () {
    final f = Filtre({'il': 'Salihli, Manisa', 'mesafe': '50'});
    final p = f.rpc('');
    expect(p['p_radius_km'], 50);
    expect(p['p_lat'] as double, closeTo(38.48, .05));
    expect(p.containsKey('p_il'), isFalse);
    expect(f.aktif().single.metin, 'Salihli, Manisa · 50 km');
    final g = Filtre({'il': 'manisa'}).rpc('');
    expect(g['p_il'], 'Manisa');
    Filtre.profilKonumu = () => (lat: 39.0, lng: 30.0);
    final h = Filtre({'sirala': 'En yakın'}).rpc('');
    expect(h['p_sort'], 'en_yakin');
    expect(h['p_lat'], 39.0);
    Filtre.profilKonumu = null;
  });

  test('telefon biçimi ve teklif mesajı', () {
    final b = TelefonBicimi();
    expect(b.formatEditUpdate(TextEditingValue.empty, const TextEditingValue(text: '05559999999')).text, '555 999 99 99');
    expect(b.formatEditUpdate(TextEditingValue.empty, const TextEditingValue(text: '+90 555 9999999')).text, '555 999 99 99');
    final m = Mesaj.json({'id': 'm', 'sender_id': 's', 'body': 'x', 'created_at': '2026-11-12T10:00:00Z', 'tur': 'teklif', 'tutar': 16000});
    expect(m.teklif, isTrue);
    expect(m.yanit, isNull);
    expect(Mesaj.json({'id': 'm', 'sender_id': 's', 'body': 'x', 'created_at': '2026-11-12T10:00:00Z'}).teklif, isFalse);
  });

  for (final olcek in [1.0, 1.25]) {
    testWidgets('ilan ver: 4 adım, alan hataları, il seçici (320 px, yazı $olcek)', (t) async {
      await ac(t, const SellScreen(), genislik: 320, yukseklik: 760, olcek: olcek);
      expect(find.text('Adım 1/4 · Hayvan'), findsOneWidget);
      await dokun(t, find.text('Devam'));
      expect(find.text('Hayvan türünü seç.'), findsOneWidget);
      await dokun(t, find.text('Küçükbaş'));
      await dokun(t, find.text('Devam'));
      expect(find.text('Cinsi seç.', skipOffstage: false), findsOneWidget);
      await dokun(t, find.text('Kıvırcık'));
      await dokun(t, find.text('Devam'));
      expect(find.text('Adım 2/4 · Yaş, ağırlık ve fiyat'), findsOneWidget);
      await dokun(t, find.text('Devam'));
      expect(find.text('Yaşı ay olarak yaz (1 yaş = 12 ay).'), findsOneWidget);
      expect(find.text('Canlı ağırlığı yaz.'), findsOneWidget);
      final alanlar = find.byType(TextField, skipOffstage: false);
      await t.enterText(alanlar.at(0), '10');
      await t.enterText(alanlar.at(1), '4');
      await t.enterText(alanlar.at(2), '18000');
      await dokun(t, find.text('Devam'));
      expect(find.textContaining('Kg fiyatı 4.500 ₺ çıkıyor'), findsOneWidget);
      await t.ensureVisible(alanlar.at(1));
      await t.pumpAndSettle();
      await t.enterText(alanlar.at(1), '45');
      await dokun(t, find.text('Devam'));
      expect(find.text('Adım 3/4 · Konum ve belgeler'), findsOneWidget);
      await dokun(t, find.text('Devam'));
      expect(find.text('Hayvanın bulunduğu il ve ilçeyi seç.'), findsOneWidget);
      await dokun(t, find.text('İl ve ilçe'));
      await t.enterText(find.byType(TextField).last, 'manısa');
      await t.pump();
      await dokun(t, find.text('Manisa'));
      await t.enterText(find.byType(TextField).last, 'SALİH');
      await t.pump();
      await dokun(t, find.text('Salihli'));
      expect(find.text('Salihli, Manisa'), findsOneWidget);
      await dokun(t, find.text('Devam'));
      expect(find.text('Adım 4/4 · Fotoğraf ve açıklama'), findsOneWidget);
      await dokun(t, find.text('İlanı yayınla'));
      expect(find.text('En az 3 fotoğraf ekle (şu an 0).'), findsOneWidget);
      await dokun(t, find.text('Geri'));
      expect(find.text('Adım 3/4 · Konum ve belgeler'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('il seçici: arama ve "Tüm il" seçeneği', (t) async {
    ({String il, String? ilce})? sonuc;
    await ac(
      t,
      Builder(
        builder: (c) => Scaffold(
          body: Center(child: TextButton(onPressed: () async => sonuc = await konumSec(c, ilceZorunlu: false), child: const Text('aç'))),
        ),
      ),
      genislik: 320,
      olcek: 1.25,
    );
    await dokun(t, find.text('aç'));
    expect(find.text('İl seç'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'izm');
    await t.pump();
    expect(find.text('İzmir'), findsOneWidget);
    expect(find.text('Manisa'), findsNothing);
    await dokun(t, find.text('İzmir'));
    await dokun(t, find.text('Tüm İzmir'));
    expect(sonuc, (il: 'İzmir', ilce: null));
    expect(t.takeException(), isNull);
  });

  testWidgets('yardım, şartlar ve bize yaz çizilir', (t) async {
    await ac(t, const YardimScreen(), genislik: 320, olcek: 1.25);
    expect(find.text('Sık sorulan sorular'), findsOneWidget);
    await dokun(t, find.text('Teklif nasıl çalışır?'));
    expect(find.textContaining('Kabul et'), findsOneWidget);
    await dokun(t, find.text('KVKK aydınlatma metni'));
    expect(find.textContaining('TASLAK'), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    await dokun(t, find.text('Bize yaz'));
    await dokun(t, find.text('Gönder'));
    expect(find.text('Birkaç kelimeyle anlat (en az 5 karakter).'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
