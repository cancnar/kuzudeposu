import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data.dart';
import 'models.dart';

/// Sayfadan bağımsız bildirim (ör. oturum kapatılınca karşılama ekranında göstermek için).
final mesajAnahtari = GlobalKey<ScaffoldMessengerState>();

class AppState extends ChangeNotifier {
  Map<String, dynamic>? profil;
  bool profilHazir = false;
  String? profilHata;
  bool misafir = false;
  bool yonetici = false;

  /// Girişten (ve profil kurulumundan) sonra açılacak ilan. Shell bunu bir kez açar ve temizler.
  String? bekleyenIlanId;

  /// Paylaşılan bağlantıyla (?ilan=…) gelen ilan; giriş beklemeden açılır.
  String? paylasilanIlanId;
  Set<String> favoriler = {};
  int okunmamisBildirim = 0;
  int okunmamisMesaj = 0;
  Filtre filtre = Filtre();
  String arama = '';
  int ilanSurum = 0;
  String yazi = 'Normal';
  int sekme = 0;
  int anaSekme = 0; // 0: ilanlar, 1: alıcı talepleri
  final Map<String, bool> tercih = {
    'msg': true,
    'newl': true,
    'price': true,
    'expire': true,
    'promo': false,
    'quiet': true,
    'photo': true,
    'online': false,
    'azalt': false,
  };
  String? _uid;
  Timer? _sayac;
  SharedPreferences? _p;
  String? _cihaz;

  /// Kullanım sayımı için rastgele, kişisel bilgi içermeyen cihaz kimliği (bir kez üretilir, cihazda saklanır).
  String get cihazKimligi {
    if (_cihaz != null) return _cihaz!;
    var k = _p?.getString('cihaz');
    if (k == null) {
      final r = Random.secure();
      k = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      _p?.setString('cihaz', k);
    }
    return _cihaz = k;
  }

  static String get platformAdi => kIsWeb
      ? 'web'
      : switch (defaultTargetPlatform) {
          TargetPlatform.iOS => 'ios',
          TargetPlatform.android => 'android',
          _ => 'diger',
        };

  /// Yerel/CI açılışları (localhost: ekran görüntüsü robotu, geliştirme) sayılmaz.
  void ziyaretBildir() {
    if (kIsWeb && const {'localhost', '127.0.0.1'}.contains(Uri.base.host)) return;
    ziyaretKaydet(cihazKimligi, platformAdi);
  }

  double get yaziOlcek => switch (yazi) {
        'Büyük' => 1.12,
        'Çok büyük' => 1.25,
        _ => 1.0,
      };

  Future<void> baslat() async {
    try {
      _p = await SharedPreferences.getInstance();
      yazi = _p!.getString('yazi') ?? 'Normal';
      for (final k in tercih.keys.toList()) {
        tercih[k] = _p!.getBool('p_$k') ?? tercih[k]!;
      }
    } catch (_) {}
  }

  void yaziDegistir(String y) {
    yazi = y;
    _p?.setString('yazi', y);
    notifyListeners();
  }

  void tercihDegistir(String k) {
    tercih[k] = !(tercih[k] ?? false);
    _p?.setBool('p_$k', tercih[k]!);
    notifyListeners();
  }

  Future<void> oturumDegisti(Session? s) async {
    if (s == null) {
      _uid = null;
      profil = null;
      profilHazir = false;
      profilHata = null;
      favoriler = {};
      okunmamisBildirim = 0;
      okunmamisMesaj = 0;
      yonetici = false;
      sekme = 0;
      _sayac?.cancel();
      notifyListeners();
      return;
    }
    if (_uid == s.user.id && profilHazir) return;
    _uid = s.user.id;
    await profilYukle();
  }

  Future<void> profilYukle() async {
    profilHazir = false;
    profilHata = null;
    notifyListeners();
    try {
      profil = await db.from('profiles').select().eq('id', uid!).maybeSingle();
      if (profil == null && !await hesapVarMi()) {
        // Hesap başka bir cihazda silinmiş ama bu tarayıcıdaki oturum açık kalmış.
        profilHazir = true;
        await oturumuKapat('Oturumun sona erdi. Devam etmek için tekrar giriş yap.');
        notifyListeners();
        return;
      }
      if (profil != null) {
        favoriler = await favoriIdleri();
        yonetici = await yoneticiMi();
        ziyaretBildir();
        await sayaclariYenile();
        _sayac?.cancel();
        _sayac = Timer.periodic(const Duration(seconds: 30), (_) => sayaclariYenile());
      }
    } catch (e) {
      profilHata = '$e';
    }
    profilHazir = true;
    notifyListeners();
  }

  /// Oturumdaki kullanıcı sunucuda hâlâ var mı? Ağ hatasında var sayılır (yanlışlıkla çıkış yapılmasın).
  Future<bool> hesapVarMi() async {
    try {
      await db.auth.getUser();
      return true;
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      return !(e.statusCode == '403' || e.statusCode == '404' || m.contains('not exist') || m.contains('not found'));
    } catch (_) {
      return true;
    }
  }

  /// Oturumu kapatır ve karşılama ekranında açıklama gösterir.
  Future<void> oturumuKapat(String mesaj) async {
    misafir = false;
    try {
      await db.auth.signOut();
    } catch (_) {
      // Sunucu oturumu zaten tanımıyorsa yerelde kapat.
      await db.auth.signOut(scope: SignOutScope.local);
    }
    mesajAnahtari.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mesaj), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 5)));
  }

  Future<void> sayaclariYenile() async {
    if (db.auth.currentSession == null) return;
    try {
      okunmamisBildirim = await okunmamisBildirimSayisi();
      okunmamisMesaj = await okunmamisMesajSayisi();
      notifyListeners();
    } catch (_) {}
  }

  void ilanlariYenile() {
    ilanSurum++;
    notifyListeners();
  }

  void yenile() => notifyListeners();
}

final app = AppState();
