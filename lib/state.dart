import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data.dart';
import 'models.dart';

class AppState extends ChangeNotifier {
  Map<String, dynamic>? profil;
  bool profilHazir = false;
  String? profilHata;
  bool misafir = false;
  Set<String> favoriler = {};
  int okunmamisBildirim = 0;
  int okunmamisMesaj = 0;
  Filtre filtre = Filtre();
  String arama = '';
  int ilanSurum = 0;
  String yazi = 'Normal';
  int sekme = 0;
  final Map<String, bool> tercih = {
    'msg': true,
    'newl': true,
    'price': true,
    'expire': true,
    'promo': false,
    'quiet': true,
    'photo': true,
    'online': false,
  };
  String? _uid;
  Timer? _sayac;
  SharedPreferences? _p;

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
      if (profil != null) {
        favoriler = await favoriIdleri();
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
