// Yönetici paneli ve moderasyon ekranları: örnek veri kaynağıyla (OrnekKaynak) çizim ve akış testleri.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kuzu_deposu/models.dart';
import 'package:kuzu_deposu/screens/admin_moderasyon.dart';
import 'package:kuzu_deposu/screens/admin_screen.dart';
import 'package:kuzu_deposu/theme.dart';
import 'package:kuzu_deposu/yonetim.dart';

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

void main() {
  setUp(() => yonetim = OrnekKaynak());

  test('yönetici özeti ve moderasyon alanları okunur', () async {
    final o = YoneticiOzet(onizlemeOzeti);
    expect(o.n('kullanim', 'toplam_cihaz'), 1250);
    expect(o.n('ilanlar', 'aktif'), 87);
    expect(o.n('yok', 'yok'), 0);
    expect(o.dagilim('ilanlar', 'tur')['kucukbas'], 60);
    expect(o.iller.first.il, 'Manisa');
    expect(o.gunluk.length, 14);
    expect(o.gunluk.last.cihaz, 140);
    expect(o.moderasyon, isNull);
    final m = (await OrnekKaynak().ozet()).moderasyon!;
    expect(m['sikayet_yeni'], 3);
    expect(m['onay_bekleyen'], 1);
    expect(m['supheli'], 2);
    expect(telefonYaz('905442223344'), '+90 544 222 33 44');
  });

  test('ilan durum yazısı moderasyonu önceler', () {
    Ilan i(String durum, String? mod) => Ilan(
        id: 'x', saticiId: 's', tur: 'kucukbas', cins: 'Kıvırcık', cinsiyet: 'erkek', adet: 1, yasMin: 10, yasMax: 10, agirlik: 40,
        toplam: 20000, satisSekli: 'birlikte', il: 'Manisa', ilce: 'Salihli', durum: durum, moderasyon: mod, olusturma: DateTime(2026));
    expect(i('aktif', null).durumAd, 'Yayında');
    expect(i('pasif', null).durumAd, 'Yayında değil');
    expect(i('pasif', 'onay_bekliyor').durumAd, 'Onay bekliyor');
    expect(i('pasif', 'otomatik_gizlendi').durumAd, 'İncelemede');
    expect(i('kaldirildi', 'yonetici_kaldirdi').durumAd, 'Kaldırıldı');
  });

  for (final genislik in [320.0, 390.0, 700.0]) {
    for (final olcek in [1.0, 1.25]) {
      testWidgets('yönetici paneli çizilir, taşmaz ($genislik px, yazı $olcek)', (t) async {
        await ac(t, const YoneticiScreen(), genislik: genislik, yukseklik: 4200, olcek: olcek);
        expect(t.takeException(), isNull);
        expect(find.text('Yönetici paneli'), findsOneWidget);
        expect(find.text('Bekleyen şikâyet'), findsOneWidget);
        expect(find.text('Şüpheli ilan'), findsOneWidget);
        expect(find.text('Ön onay modu'), findsOneWidget);
        expect(find.text('Uygulamayı kullanan'), findsOneWidget);
        expect(find.text('1.250'), findsOneWidget);
        await t.tap(find.text('Yeni ilan'));
        await t.pump();
        expect(t.takeException(), isNull);
      });
    }
  }

  testWidgets('yönetici paneli: yetkisiz kullanıcıya uyarı', (t) async {
    await ac(t, YoneticiScreen(yukle: () async => throw Exception('yetki yok: bu bilgiler sadece yöneticiye açık')));
    expect(find.text('Bu sayfa sadece yöneticilere açık.'), findsOneWidget);
  });

  testWidgets('009 yoksa moderasyon bölümü uyarı verir', (t) async {
    await ac(t, YoneticiScreen(yukle: () async => YoneticiOzet(Map<String, dynamic>.from(onizlemeOzeti))));
    expect(find.textContaining('009_moderasyon.sql'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('şüpheli ilanı gerekçeyle gizle', (t) async {
    await ac(t, const YoneticiScreen());
    await t.tap(find.text('Şüpheli ilan'));
    await t.pumpAndSettle();
    expect(find.text('Şüpheli ilanlar'), findsOneWidget);
    expect(find.text('IBAN'), findsOneWidget);
    await t.tap(find.text('Holstein düve'));
    await t.pumpAndSettle();
    expect(find.text('Kalıcı olarak kaldır'), findsOneWidget);
    await t.tap(find.text('Yayından gizle'));
    await t.pumpAndSettle();
    expect(find.text('Neden gizleniyor?'), findsOneWidget);
    await t.tap(find.text('Kapora / ön ödeme istiyor'));
    await t.pump();
    await t.tap(find.text('Yayından gizle'));
    await t.pumpAndSettle();
    expect(find.text('İlan gizlendi, satıcıya bildirildi'), findsOneWidget);
    expect(find.text('Holstein düve'), findsNothing);
    expect(find.text('Akkaraman toklu'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('onay bekleyen ilanı onayla', (t) async {
    await ac(t, const YoneticiIlanlarScreen(filtre: 'onay', baslikYazi: 'Onay bekleyenler'));
    await t.tap(find.text('Kıvırcık kuzu'));
    await t.pumpAndSettle();
    await t.tap(find.text('Onayla ve yayınla'));
    await t.pumpAndSettle();
    expect(find.text('İlan onaylandı ve yayına çıktı'), findsOneWidget);
    expect(find.text('Liste boş'), findsOneWidget);
  });

  for (final olcek in [1.0, 1.25]) {
    testWidgets('kullanıcıyı ara ve askıya al (yazı $olcek)', (t) async {
      await ac(t, const KullanicilarScreen(), genislik: 320, olcek: olcek);
      expect(t.takeException(), isNull);
      await t.enterText(find.byType(TextField), '2233');
      await t.testTextInput.receiveAction(TextInputAction.search);
      await t.pumpAndSettle();
      expect(find.text('Sabri Kaya'), findsOneWidget);
      expect(find.text('Hatice Demir'), findsOneWidget);
      expect(find.text('Mustafa Koç'), findsNothing);
      await t.tap(find.text('Sabri Kaya'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('+90 544 222 33 44'), findsOneWidget);
      await t.scrollUntilVisible(find.text('Hesabı askıya al'), 200, scrollable: find.byType(Scrollable).first);
      await t.tap(find.text('Hesabı askıya al'));
      await t.pumpAndSettle();
      await t.tap(find.text('Kapora istiyor'));
      await t.pump();
      await t.tap(find.text('Hesabı askıya al').last);
      await t.pumpAndSettle();
      expect(find.text('Hesap askıda: Kapora istiyor'), findsOneWidget);
      expect(find.text('Askıyı kaldır'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  for (final olcek in [1.0, 1.25]) {
    testWidgets('şikâyet kutusu: çizilir, kapatılır (320 px, yazı $olcek)', (t) async {
      await ac(t, const SikayetlerScreen(), genislik: 320, yukseklik: 2400, olcek: olcek);
      expect(t.takeException(), isNull);
      expect(find.text('Kapora / ön ödeme istiyor'), findsOneWidget);
      expect(find.text('Bu ilanı 2 farklı kişi şikâyet etti'), findsNWidgets(2));
      await t.tap(find.text('Kapat').first);
      await t.pumpAndSettle();
      expect(find.text('Şikâyet kapatıldı'), findsOneWidget);
      expect(find.text('Kapora / ön ödeme istiyor'), findsNothing);
      await t.tap(find.text('İnceleniyor'));
      await t.pumpAndSettle();
      expect(find.text('Sahte ilan'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
