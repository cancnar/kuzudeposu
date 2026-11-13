// Gerçek Supabase projesine karşı uçtan uca test (CI'da çalışır).
// Test kullanıcısı: 555 999 99 99 (Supabase'de test numarası olarak 905559999999=123456 tanımlı olmalı).
// Gerçek kullanıcı hesaplarına dokunmaz: o numarada profil varsa test durur. Sonunda test hesabı silinir.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kuzu_deposu/config.dart';
import 'package:kuzu_deposu/data.dart';
import 'package:kuzu_deposu/models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const testNo = '+905559999999';
final sonuc = <String>[];
int hataSayisi = 0;

Future<T?> adim<T>(String ad, Future<T> Function() f) async {
  try {
    final r = await f();
    sonuc.add('ADIM OK    $ad');
    return r;
  } catch (e) {
    hataSayisi++;
    sonuc.add('ADIM HATA  $ad -> $e');
    return null;
  }
}

void sart(bool k, String mesaj) {
  if (!k) throw mesaj;
}

// 1x1 geçerli PNG
final png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0,
  0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  test('canlı veri tabanı uçtan uca', () async {
    testIstemci = SupabaseClient(supabaseUrl, supabasePublishableKey);
    final olusanFotolar = <String>[];
    String? kendiIlan;
    var onOnay = false; // 009: yönetici "ön onay"ı açtıysa yeni ilan aramada görünmez (doğru davranış)
    var profilBizim = false;
    try {
      // ---------- Misafir (giriş yok) ----------
      final liste = await adim('misafir: ilan arama (filtresiz)', () async {
        final l = await ilanAra('', Filtre());
        sonuc.add('   bilgi: ${l.length} ilan döndü');
        sart(l.isNotEmpty, 'hiç ilan yok (seed_ornek_ilanlar.sql çalıştırıldı mı?)');
        for (final i in l) {
          sart(i.cins.isNotEmpty && i.kgFiyat > 0 && i.saticiAd.isNotEmpty, 'bozuk ilan verisi: ${i.id}');
        }
        return l;
      });
      await adim('misafir: tür filtresi (Büyükbaş)', () async {
        final l = await ilanAra('', Filtre({'tur': 'Büyükbaş'}));
        sart(l.isNotEmpty && l.every((i) => i.tur == 'buyukbas'), 'tür filtresi yanlış (${l.length})');
      });
      await adim('misafir: sürü / tek hayvan filtresi', () async {
        final s = await ilanAra('', Filtre({'satis': 'Sürü'}));
        final t = await ilanAra('', Filtre({'satis': 'Tek hayvan'}));
        sart(s.isNotEmpty && s.every((i) => i.adet > 1), 'sürü filtresi yanlış');
        sart(t.isNotEmpty && t.every((i) => i.adet == 1), 'tek hayvan filtresi yanlış');
      });
      await adim('misafir: yaş aralığı kesişimi (12–14 ay)', () async {
        final l = await ilanAra('', Filtre({'yasMin': '12', 'yasMax': '14'}));
        sart(l.isNotEmpty && l.every((i) => i.yasMin <= 14 && i.yasMax >= 12), 'yaş filtresi yanlış');
      });
      await adim('misafir: fiyat sıralaması', () async {
        final l = await ilanAra('', Filtre({'sirala': 'Fiyat: artan'}));
        for (var i = 1; i < l.length; i++) {
          sart(l[i - 1].toplam <= l[i].toplam, 'artan sıralama bozuk');
        }
        final d = await ilanAra('', Filtre({'sirala': 'Fiyat: azalan'}));
        for (var i = 1; i < d.length; i++) {
          sart(d[i - 1].toplam >= d[i].toplam, 'azalan sıralama bozuk');
        }
      });
      await adim('misafir: konum + metin araması', () async {
        final a = await ilanAra('', Filtre({'il': 'Konya'}));
        sart(a.isNotEmpty && a.every((i) => '${i.il} ${i.ilce}'.toLowerCase().contains('konya')), 'konum filtresi yanlış');
        final b = await ilanAra('kıvırcık', Filtre());
        sart(b.isNotEmpty && b.every((i) => i.cins.toLowerCase().contains('kıvırcık')), 'metin araması yanlış');
        final c = await ilanAra('zzzyok', Filtre());
        sart(c.isEmpty, 'olmayan aramada sonuç geldi');
      });
      await adim('misafir: eş anlamlı arama ve il + mesafe (011)', () async {
        final k = await ilanAra('koyun', Filtre());
        if (k.isEmpty) {
          sonuc.add('   bilgi: "koyun" sonuç vermedi; 011 çalıştırılmamış olabilir');
        } else {
          sart(k.every((i) => i.tur == 'kucukbas' && !i.cins.toLowerCase().contains('keçi')), '"koyun" araması küçükbaş koyun dışı ilan getirdi');
        }
        final b = await ilanAra('inek', Filtre());
        sart(b.every((i) => i.tur == 'buyukbas'), '"inek" araması büyükbaş dışı ilan getirdi (ör. "binek")');
        final sadece = await ilanAra('', Filtre({'il': 'Manisa'}));
        final yaricap = await ilanAra('', Filtre({'il': 'Manisa', 'mesafe': '100'}));
        final eksik = sadece.where((i) => !yaricap.any((y) => y.id == i.id)).map((i) => i.ilce).toList();
        if (eksik.isNotEmpty) sonuc.add('   bilgi: Manisa · 100 km, ildeki şu ilçeleri kapsamadı: $eksik (011 çalıştırılmamış olabilir)');
      });
      await adim('misafir: tüm filtreler birlikte (hata vermemeli)', () async {
        await ilanAra('a', Filtre({
          'tur': 'Küçükbaş', 'cins': 'Ak', 'satis': 'Sürü', 'adetMin': '2', 'adetMax': '500', 'yasMin': '1', 'yasMax': '60',
          'kgMin': '10', 'kgMax': '900', 'fiyatMin': '1000', 'fiyatMax': '9000000', 'il': 'Konya', 'sirala': 'Fiyat: artan',
        }));
      });
      final ilk = liste != null && liste.isNotEmpty ? liste.first : null;
      await adim('misafir: ilan detayı + yorumlar', () async {
        sart(ilk != null, 'ilan yok');
        final d = await ilanGetir(ilk!.id);
        sart(d != null && d.id == ilk.id, 'ilanGetir boş');
        await yorumlar(ilk.saticiId);
      });

      await adim('misafir: satıcı profili (profil + aktif + satılan + yorumlar)', () async {
        sart(ilk != null, 'ilan yok');
        final pr = await saticiProfil(ilk!.saticiId);
        sart(pr != null && (pr['full_name'] as String).isNotEmpty, 'satıcı profili okunamadı');
        final a = await saticiIlanlari(ilk.saticiId, 'aktif');
        sart(a.isNotEmpty && a.every((i) => i.aktif && i.saticiId == ilk.saticiId), 'aktif ilanlar yanlış');
        final st = await saticiIlanlari(ilk.saticiId, 'satildi');
        sart(st.every((i) => i.durum == 'satildi'), 'satılan ilanlar yanlış');
        sonuc.add('   bilgi: satıcının ${a.length} aktif, ${st.length} satılmış ilanı var (satılmışlar için 003 + seed gerekir)');
        final y = await yorumlar(ilk.saticiId);
        sonuc.add('   bilgi: satıcının ${y.length} yorumu var');
      });

      // ---------- Giriş ----------
      await adim('giriş: telefon kodu gönder + doğrula (test numarası)', () async {
        await db.auth.signInWithOtp(phone: testNo);
        final r = await db.auth.verifyOTP(phone: testNo, token: '123456', type: OtpType.sms);
        sart(r.session != null && uid != null, 'oturum açılamadı');
      });
      if (uid == null) {
        sonuc.add('Oturum açılamadığı için sonraki adımlar atlandı. Supabase > Authentication > Phone ayarlarını kontrol et.');
      } else {
        var mevcut = await db.from('profiles').select().eq('id', uid!).maybeSingle();
        if (mevcut != null && mevcut['full_name'] == 'CI Test Kullanıcı') {
          // Önceki testten kalan test hesabı: sil ve sıfırdan başla.
          try {
            await db.rpc('hesabimi_sil');
            await db.auth.signOut();
            await db.auth.signInWithOtp(phone: testNo);
            await db.auth.verifyOTP(phone: testNo, token: '123456', type: OtpType.sms);
            mevcut = await db.from('profiles').select().eq('id', uid!).maybeSingle();
            sonuc.add('ADIM OK    önceki test hesabı silindi, temiz başlangıç');
          } catch (e) {
            hataSayisi++;
            sonuc.add('ADIM HATA  önceki test hesabı silinemedi (002_ek_ozellikler.sql çalıştırıldı mı?) -> $e');
            return;
          }
        }
        if (mevcut != null) {
          hataSayisi++;
          sonuc.add('ADIM HATA  bu numarada gerçek bir profil var; test güvenlik için durdu (ayrı test numarası kullan)');
          return;
        }
        profilBizim = true;
        sonuc.add('ADIM OK    giriş sonrası: profil henüz yok');
        await adim('okuma sorguları (söz dizimi kontrolü)', () async {
          await favoriIlanlar();
          await favoriIdleri();
          await benimIlanlarim();
          await konusmalar();
          await bildirimler();
          await kayitliAramalar();
          await engellenenler();
          await okunmamisBildirimSayisi();
          await okunmamisMesajSayisi();
        });
        await adim('profil oluştur', () async {
          await db.from('profiles').insert({'id': uid, 'full_name': 'CI Test Kullanıcı', 'il': 'Manisa', 'ilce': 'Salihli', 'role': 'alici'});
          final p = await db.from('profiles').select().eq('id', uid!).maybeSingle();
          sart(p != null && p['full_name'] == 'CI Test Kullanıcı', 'profil okunamadı');
        });
        await adim('ilan ver: kayıt + 3 fotoğraf yükleme (Storage)', () async {
          final id = await ilanVer({
            'seller_id': uid, 'tur': 'kucukbas', 'cins': 'Akkaraman', 'cinsiyet': 'karisik', 'adet': 10, 'yas_min': 10, 'yas_max': 14,
            'agirlik_kg': 55, 'toplam_fiyat': 220000, 'satis_sekli': 'adet_adet', 'aciklama': 'CI test ilanı', 'il': 'Manisa', 'ilce': 'Salihli',
            'amac': 'kurbanlik', 'belgeler': ['kupe', 'saglik_raporu'], 'pazarlik': true, 'teslimat': 'ikisi',
          }, [FotoDosya(png, 'a.png', 'image/png'), FotoDosya(png, 'b.png', 'image/png'), FotoDosya(png, 'c.png', 'image/png')]);
          kendiIlan = id;
          onOnay = await ilanOnayBekliyor(id);
          if (onOnay) sonuc.add('   bilgi: ön onay modu açık; ilan onay bekliyor, arama adımları buna göre denetleniyor');
          final i = await ilanGetir(id);
          sart(i != null && i.foto.length == 3, 'fotoğraf sayısı: ${i?.foto.length}');
          sart(i!.kgFiyat == 400, 'kg fiyatı ${i.kgFiyat} (400 bekleniyordu)');
          olusanFotolar.addAll(['${uid!}/$id/0.png', '${uid!}/$id/1.png', '${uid!}/$id/2.png']);
          final c = HttpClient();
          final res = await (await c.getUrl(Uri.parse(i.foto.first))).close();
          sart(res.statusCode == 200, 'fotoğraf adresi ${res.statusCode} döndü');
          c.close(force: true);
        });
        await adim('ilanlarım + aramada görünme', () async {
          final m = await benimIlanlarim();
          sart(m.any((i) => i.id == kendiIlan), 'ilanlarım listesinde yok');
          final a = await ilanAra('', Filtre({'il': 'Salihli'}));
          if (onOnay) {
            sart(!a.any((i) => i.id == kendiIlan), 'onay bekleyen ilan aramada görünüyor!');
          } else {
            sart(a.any((i) => i.id == kendiIlan), 'aramada görünmüyor');
          }
        });
        await adim('yeni alanlar: amaç / belge filtresi, fiyat özeti, görüntülenme, istatistik', () async {
          final i = await ilanGetir(kendiIlan!);
          sart(i!.amac == 'kurbanlik' && i.pazarlik && i.teslimat == 'ikisi' && i.belgeler.length == 2, 'yeni alanlar okunamadı');
          final a = await ilanAra('', Filtre({'amac': 'Kurbanlık', 'belgeler': 'kupe,saglik_raporu'}));
          if (!onOnay) sart(a.any((x) => x.id == kendiIlan), 'amaç + belge filtresiyle bulunamadı');
          final b = await ilanAra('', Filtre({'amac': 'Besilik'}));
          sart(!b.any((x) => x.id == kendiIlan), 'yanlış amaçta göründü');
          final o = await fiyatOzeti(i);
          sart(o == null || o.medyan > 0, 'fiyat özeti bozuk');
          final st = await ilanIstatistik(kendiIlan!);
          sart(st != null && st['goruntulenme'] != null, 'istatistik alınamadı');
          await ilanGoruntule(kendiIlan!);
        });
        await adim('ilan süresini 30 gün uzat', () async {
          final once = (await ilanGetir(kendiIlan!))!;
          await ilanUzat(once);
          final sonra = (await ilanGetir(kendiIlan!))!;
          sart(sonra.bitis != null && once.bitis != null && sonra.bitis!.difference(once.bitis!).inDays >= 29, 'süre uzamadı');
        });
        await adim('alıcı talebi: yayınla → listede → kapat', () async {
          final id = await talepVer({'buyer_id': uid, 'tur': 'kucukbas', 'cins': 'Akkaraman', 'adet': 3, 'amac': 'kurbanlik', 'butce_max': 90000, 'il': 'Manisa', 'aciklama': 'CI test talebi'});
          final l = await talepler(tur: 'kucukbas');
          sart(l.any((x) => x.id == id), 'talep listede yok');
          final b = await taleplerim();
          sart(b.any((x) => x.id == id && x.aliciAd.isNotEmpty), 'taleplerim boş');
          await talepKapat(id);
          final k = await talepler(tur: 'kucukbas');
          sart(!k.any((x) => x.id == id), 'kapatılan talep hâlâ listede');
        });
        await adim('video yükle (listing-videos) + oynatma adresi', () async {
          final id = await ilanVer({
            'seller_id': uid, 'tur': 'kucukbas', 'cins': 'Akkaraman', 'cinsiyet': 'erkek', 'adet': 1, 'yas_min': 8, 'yas_max': 8,
            'agirlik_kg': 50, 'toplam_fiyat': 20000, 'aciklama': 'CI video testi', 'il': 'Manisa', 'ilce': 'Salihli',
          }, [FotoDosya(png, 'a.png', 'image/png'), FotoDosya(png, 'b.png', 'image/png'), FotoDosya(png, 'c.png', 'image/png')],
              video: FotoDosya(Uint8List.fromList(List.filled(2048, 0)), 'klip.mp4', 'video/mp4'));
          olusanFotolar.addAll(['${uid!}/$id/0.png', '${uid!}/$id/1.png', '${uid!}/$id/2.png']);
          final i = await ilanGetir(id);
          sart(i != null && i.videoVar, 'video yolu kaydedilmedi');
          final c = HttpClient();
          final res = await (await c.getUrl(Uri.parse(videoUrl(i!.videoYol!)))).close();
          sart(res.statusCode == 200, 'video adresi ${res.statusCode} döndü');
          c.close(force: true);
          await db.storage.from('listing-videos').remove([i.videoYol!]);
          await db.from('listings').delete().eq('id', id);
        });
        final baskasi = liste?.where((i) => i.saticiId != uid).toList() ?? [];
        if (baskasi.isEmpty) {
          sonuc.add('ADIM HATA  başkasının ilanı yok, mesajlaşma testleri atlandı');
          hataSayisi++;
        } else {
          final hedef = baskasi.first;
          await adim('favori ekle / listele / çıkar', () async {
            await favoriDegistir(hedef.id, true);
            sart((await favoriIdleri()).contains(hedef.id), 'favori id yok');
            sart((await favoriIlanlar()).any((i) => i.id == hedef.id), 'favori listesinde yok');
            await favoriDegistir(hedef.id, false);
            sart(!(await favoriIdleri()).contains(hedef.id), 'favori silinmedi');
          });
          await adim('kayıtlı arama ekle / aç-kapat / sil', () async {
            await aramaKaydet('CI arama', Filtre({'tur': 'Küçükbaş', 'cins': 'Akkaraman'}));
            final l = await kayitliAramalar();
            sart(l.length == 1, 'kayıtlı arama sayısı ${l.length}');
            sart(Filtre.json(l.first['filters'])['tur'] == 'Küçükbaş', 'filtre geri okunamadı');
            await aramaBildirim(l.first['id'] as String, false);
            await aramaSil(l.first['id'] as String);
          });
          String? konId;
          await adim('mesajlaşma: konuşma aç + mesaj gönder + listele', () async {
            konId = await konusmaAc(hedef);
            sart(konId == await konusmaAc(hedef), 'aynı ilana ikinci konuşma açıldı');
            await mesajGonder(konId!, 'Merhaba, CI testi');
            final k = await konusmaGetir(konId!);
            sart(k != null && k.alici && k.karsiId == hedef.saticiId, 'konuşma bilgisi yanlış');
            final l = await konusmalar();
            final bu = l.where((x) => x.id == konId).toList();
            sart(bu.length == 1 && bu.first.son?.metin == 'Merhaba, CI testi', 'son mesaj yanlış');
          });
          await adim('mesajlaşma: gerçek zamanlı akış (stream)', () async {
            final ilkVeri = await db.from('messages').stream(primaryKey: ['id']).eq('conversation_id', konId!).order('created_at').first.timeout(const Duration(seconds: 20));
            sart(ilkVeri.length == 1, 'akış ${ilkVeri.length} mesaj döndü');
          });
          await adim('mesajlaşma: okundu işareti', () async {
            await okunduIsaretle(konId!);
          });
          await adim('yorum: satıcı yanıt vermeden yazılamaz (011)', () async {
            // Örnek satıcı hiç yanıt vermediği için 011'den sonra değerlendirme reddedilmeli.
            final yazildi = await yorumYaz(konId!, hedef.saticiId, 4, 'CI yorumu').then((_) => true).catchError((_) => false);
            if (!yazildi) return;
            sonuc.add('   bilgi: 011 çalıştırılmamış; satıcı yanıtı olmadan yorum yazılabiliyor (eski kural)');
            final y = await yorumlar(hedef.saticiId);
            sart(y.any((e) => e['comment'] == 'CI yorumu'), 'yorum listede yok');
            final ikinci = await db.from('reviews').insert({'conversation_id': konId, 'reviewer_id': uid, 'seller_id': hedef.saticiId, 'rating': 5}).then((_) => true).catchError((_) => false);
            sart(!ikinci, 'aynı konuşmaya ikinci yorum yazılabildi');
          });
          await adim('şikayet + engelle / engeli kaldır', () async {
            await sikayetEt(ilanId: hedef.id, kullaniciId: hedef.saticiId, sebep: 'sahte_ilan', detay: 'CI testi');
            await engelle(hedef.saticiId);
            sart((await engellenenler()).length == 1, 'engel listesi yanlış');
            final ara = await ilanAra('', Filtre());
            sart(!ara.any((i) => i.saticiId == hedef.saticiId), 'engellenen satıcının ilanı hâlâ görünüyor');
            await engelKaldir(hedef.saticiId);
          });
        }
        await adim('ilan durumu: pasife al → aramada görünmesin', () async {
          await ilanDurumu(kendiIlan!, 'pasif');
          final a = await ilanAra('', Filtre({'il': 'Salihli'}));
          sart(!a.any((i) => i.id == kendiIlan), 'pasif ilan aramada görünüyor');
        });
        await adim('bildirim sorguları', () async {
          await bildirimler();
          await hepsiniOkundu();
        });
        await adim('yönetici paneli: test hesabı yönetici değil, özet kapalı (008)', () async {
          try {
            await db.rpc('yonetici_mi');
          } on PostgrestException catch (e) {
            if (e.code == 'PGRST202' || e.message.contains('Could not find')) {
              sonuc.add('   bilgi: 008_yonetici.sql henüz çalıştırılmamış, adım atlandı');
              return;
            }
            rethrow;
          }
          sart(!(await yoneticiMi()), 'test hesabı yönetici olmamalı (test kodu herkese açık)');
          var acik = true;
          try {
            await yoneticiOzet();
          } catch (e) {
            acik = false;
            sart('$e'.contains('yetki'), 'beklenmeyen hata: $e');
          }
          sart(!acik, 'yönetici olmayan kullanıcı panel verisini okuyabildi!');
          final tablo = await db.from('admins').select().then((r) => r.length).catchError((_) => -1);
          sart(tablo <= 0, 'admins tablosu uygulamadan okunabiliyor');
        });
        await adim('moderasyon (009): test hesabı moderasyon yapamaz, korumalı alanları değiştiremez', () async {
          var var009 = true;
          var acik = false;
          try {
            await db.rpc('yonetici_moderasyon_ozet');
            acik = true;
          } on PostgrestException catch (e) {
            if (e.code == 'PGRST202' || e.message.contains('Could not find')) {
              var009 = false;
            } else {
              sart(e.message.contains('yetki'), 'beklenmeyen hata: ${e.message}');
            }
          }
          if (!var009) {
            sonuc.add('   bilgi: 009_moderasyon.sql henüz çalıştırılmamış, adım atlandı');
            return;
          }
          sart(!acik, 'yönetici olmayan moderasyon özetini okuyabildi!');
          final islem = await db.rpc('yonetici_askiya_al', params: {'p_id': uid, 'p_askida': true}).then((_) => true).catchError((_) => false);
          sart(!islem, 'yönetici olmayan askıya alma yapabildi!');
          await db.from('profiles').update({'askida': true}).eq('id', uid!);
          final p = await db.from('profiles').select('askida').eq('id', uid!).single();
          sart(p['askida'] == false, 'kullanıcı kendi askida alanını değiştirebildi');
          if (kendiIlan != null) {
            final once = (await db.from('listings').select('moderasyon').eq('id', kendiIlan!).single())['moderasyon'];
            await db.from('listings').update({'moderasyon': 'yonetici_gizledi'}).eq('id', kendiIlan!);
            final r = await db.from('listings').select('moderasyon').eq('id', kendiIlan!).single();
            sart(r['moderasyon'] == once, 'kullanıcı ilanın moderasyon alanını değiştirebildi');
          }
        });
      }
    } finally {
      await adim('temizlik: fotoğrafları sil', () async {
        if (olusanFotolar.isNotEmpty) await db.storage.from('listing-photos').remove(olusanFotolar);
      });
      if (uid != null && profilBizim) {
        await adim('hesap silme (hesabimi_sil) + zincirleme temizlik', () async {
          await db.rpc('hesabimi_sil');
          await db.auth.signOut();
        });
      }
      // ignore: avoid_print
      print('\n===== TEST RAPORU =====\n${sonuc.join('\n')}\n=======================');
    }
    expect(hataSayisi, 0, reason: sonuc.where((x) => x.contains('HATA')).join(' | '));
  }, timeout: const Timeout(Duration(minutes: 4)));
}
