import 'dart:convert';

import 'konum.dart';

const turEtiket = {'buyukbas': 'Büyükbaş', 'kucukbas': 'Küçükbaş', 'kanatli': 'Kanatlı', 'at': 'At'};
final Map<String, String> turKod = {for (final e in turEtiket.entries) e.value: e.key};
const cinsiyetEtiket = {'disi': 'Dişi', 'erkek': 'Erkek', 'karisik': 'Karışık'};
const amacEtiket = {
  'kurbanlik': 'Kurbanlık',
  'besi': 'Besilik',
  'damizlik': 'Damızlık',
  'sut_yumurta': 'Süt / yumurta',
  'kesim': 'Kesimlik',
  'diger': 'Diğer',
};
final Map<String, String> amacKod = {for (final e in amacEtiket.entries) e.value: e.key};
const belgeEtiket = {
  'kupe': 'Küpeli',
  'saglik_raporu': 'Sağlık raporu',
  'pasaport': 'Pasaportlu',
  'nakil': 'Nakil belgesi',
  'asi': 'Aşıları tam',
};
final Map<String, String> belgeKod = {for (final e in belgeEtiket.entries) e.value: e.key};
const teslimatEtiket = {'yerinde': 'Yerinden teslim', 'nakliye': 'Nakliye ile', 'ikisi': 'Yerinde veya nakliye'};

const turSecenekleri = ['Büyükbaş', 'Küçükbaş', 'Kanatlı', 'At'];

/// Makul değer aralıkları (hayvan başı kg, kg fiyatı ₺). Veri tabanındaki public.ilan_makul() ile aynı tutulur;
/// fiyat sınırları enflasyonla yılda bir gözden geçirilir.
const makulAralik = <String, ({double kgMin, double kgMax, double fMin, double fMax})>{
  'buyukbas': (kgMin: 40, kgMax: 1500, fMin: 100, fMax: 3000),
  'kucukbas': (kgMin: 3, kgMax: 200, fMin: 100, fMax: 3000),
  'kanatli': (kgMin: 0.2, kgMax: 25, fMin: 20, fMax: 5000),
  'at': (kgMin: 50, kgMax: 1200, fMin: 20, fMax: 10000),
};

/// Ağırlık makul değilse hata metni (yoksa null).
String? agirlikMakul(String tur, double kg) {
  final a = makulAralik[tur];
  if (a == null) return null;
  if (kg < a.kgMin || kg > a.kgMax) return '${turEtiket[tur]} için hayvan başı ${sayi(a.kgMin)}–${sayi(a.kgMax)} kg olmalı.';
  return null;
}

/// Toplam fiyat makul değilse hata metni (yoksa null).
String? fiyatMakul(String tur, int adet, double kg, double toplam) {
  final a = makulAralik[tur];
  if (a == null || kg <= 0 || adet <= 0) return null;
  final f = toplam / (adet * kg);
  if (f < a.fMin || f > a.fMax) {
    return 'Kg fiyatı ${sayi(f)} ₺ çıkıyor; ${turEtiket[tur]!.toLowerCase()} için ${sayi(a.fMin)}–${sayi(a.fMax)} ₺/kg olmalı. Toplam fiyatı kontrol et.';
  }
  return null;
}
const cinsListesi = <String, List<String>>{
  'Büyükbaş': ['Simental', 'Holstein', 'Montofon', 'Şarole', 'Angus', 'Jersey', 'Yerli kara', 'Manda', 'Melez'],
  'Küçükbaş': ['Akkaraman', 'Merinos', 'Kıvırcık', 'Sakız', 'Dağlıç', 'Karayaka', 'İvesi', 'Saanen keçisi', 'Kıl keçisi', 'Melez'],
  'Kanatlı': ['Tavuk', 'Hindi', 'Kaz', 'Ördek'],
  'At': ['Arap', 'İngiliz', 'Rahvan', 'Yerli', 'Midilli'],
};

String sayi(num n) {
  final s = n.round().abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '${n < 0 ? '-' : ''}$b';
}

String tl(num n) => '${sayi(n)} ₺';
String puanYaz(num p) => p.toStringAsFixed(1).replaceAll('.', ',');
String yildiz(num p) {
  final k = p.round().clamp(0, 5);
  return '★' * k + '☆' * (5 - k);
}

num? sayiOku(String s) => num.tryParse(s.trim().replaceAll(',', '.'));

String _ik(int x) => x.toString().padLeft(2, '0');

String saat(DateTime t) {
  final l = t.toLocal();
  final n = DateTime.now();
  if (l.year == n.year && l.month == n.month && l.day == n.day) return '${_ik(l.hour)}:${_ik(l.minute)}';
  final dun = n.subtract(const Duration(days: 1));
  if (l.year == dun.year && l.month == dun.month && l.day == dun.day) return 'Dün';
  return '${_ik(l.day)}.${_ik(l.month)}';
}

String goreli(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 60) return 'Az önce';
  if (d.inHours < 24) return '${d.inHours} saat önce';
  if (d.inDays < 7) return '${d.inDays} gün önce';
  if (d.inDays < 30) return '${d.inDays ~/ 7} hafta önce';
  if (d.inDays < 365) return '${d.inDays ~/ 30} ay önce';
  return '${d.inDays ~/ 365} yıl önce';
}

const _aylar = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
String ayYil(DateTime t) => '${_aylar[t.toLocal().month - 1]} ${t.toLocal().year}';

String maske(String? telefon) {
  var t = (telefon ?? '').replaceAll(RegExp(r'\D'), '');
  if (t.startsWith('90') && t.length == 12) t = t.substring(2);
  if (t.length != 10) return '+90 *** *** ** **';
  return '+90 ${t.substring(0, 3)} *** ** ${t.substring(8)}';
}

const moderasyonEtiket = {
  'onay_bekliyor': 'Onay bekliyor',
  'otomatik_gizlendi': 'İncelemede',
  'yonetici_gizledi': 'Yönetici gizledi',
  'yonetici_kaldirdi': 'Kaldırıldı',
  'hesap_askida': 'Hesap askıda',
};

/// Satıcıya gösterilen açıklama (ilan detayında).
const moderasyonAciklama = {
  'onay_bekliyor': 'İlanın yönetici onayı bekliyor. Onaylanınca yayına çıkar ve sana bildirim gelir.',
  'otomatik_gizlendi': 'İlanın birden fazla şikâyet aldığı için incelemeye alındı. İnceleme bitince sana bildirim gelir.',
  'yonetici_gizledi': 'İlanın yönetici tarafından yayından kaldırıldı.',
  'yonetici_kaldirdi': 'İlanın kurallara uymadığı için kaldırıldı.',
  'hesap_askida': 'Hesabın askıya alındığı için ilanın yayında değil.',
};

/// 905321234567 → +90 532 123 45 67 (yönetici paneli için tam numara)
String telefonYaz(String? telefon) {
  var t = (telefon ?? '').replaceAll(RegExp(r'\D'), '');
  if (t.startsWith('90') && t.length == 12) t = t.substring(2);
  if (t.length != 10) return telefon ?? '';
  return '+90 ${t.substring(0, 3)} ${t.substring(3, 6)} ${t.substring(6, 8)} ${t.substring(8)}';
}

class Ilan {
  Ilan({
    required this.id,
    required this.saticiId,
    required this.tur,
    required this.cins,
    required this.cinsiyet,
    required this.adet,
    required this.yasMin,
    required this.yasMax,
    required this.agirlik,
    required this.toplam,
    required this.satisSekli,
    required this.il,
    required this.ilce,
    required this.durum,
    required this.olusturma,
    this.aciklama,
    this.mesafe,
    this.satildiAt,
    this.bitis,
    this.videoYol,
    this.amac,
    this.belgeler = const [],
    this.pazarlik = false,
    this.teslimat = 'yerinde',
    this.goruntulenme = 0,
    this.moderasyon,
    this.moderasyonNeden,
    this.saticiAd = 'Satıcı',
    this.saticiPuan = 0,
    this.saticiPuanSayisi = 0,
  });

  final String id, saticiId, tur, cins, cinsiyet, satisSekli, il, ilce, durum;
  final String? aciklama, amac, videoYol;

  /// Yönetici incelemesi (009): onay_bekliyor, otomatik_gizlendi, yonetici_gizledi, yonetici_kaldirdi, hesap_askida
  final String? moderasyon, moderasyonNeden;
  final List<String> belgeler;
  final bool pazarlik;
  final String teslimat;
  final int goruntulenme;
  final int adet, yasMin, yasMax;
  final double agirlik, toplam;
  final double? mesafe;
  final DateTime? satildiAt, bitis;
  final DateTime olusturma;
  String saticiAd;
  double saticiPuan;
  int saticiPuanSayisi;
  List<String> foto = [];

  bool get suru => adet > 1;
  String get turAd => turEtiket[tur] ?? tur;
  String get cinsiyetAd => cinsiyetEtiket[cinsiyet] ?? cinsiyet;
  String get yasMetni => suru ? '$yasMin–$yasMax ay' : '$yasMin ay';
  int get kgFiyat => (toplam / (adet * agirlik)).round();
  String get yer => '$ilce, $il';
  bool get aktif => durum == 'aktif';
  bool get videoVar => videoYol != null && videoYol!.isNotEmpty;
  int? get kalanGun => bitis == null ? null : bitis!.difference(DateTime.now()).inDays;
  String? get amacAd => amac == null ? null : amacEtiket[amac];
  String get teslimatAd => teslimatEtiket[teslimat] ?? teslimat;
  String? get moderasyonAd => moderasyon == null ? null : (moderasyonEtiket[moderasyon] ?? 'İncelemede');

  /// Listede gösterilecek kısa durum yazısı.
  String get durumAd => moderasyonAd ??
      switch (durum) {
        'aktif' => 'Yayında',
        'satildi' => 'Satıldı',
        'kaldirildi' => 'Kaldırıldı',
        _ => 'Yayında değil',
      };

  factory Ilan.json(Map<String, dynamic> j, {String? ad, num? puan, int? puanSayisi, double? mesafe}) {
    final s = j['seller'];
    String? sAd = ad;
    num? sPuan = puan;
    int? sSayi = puanSayisi;
    if (s is Map) {
      sAd ??= s['full_name'] as String?;
      sPuan ??= s['rating_avg'] as num?;
      sSayi ??= (s['rating_count'] as num?)?.toInt();
    }
    return Ilan(
      id: j['id'] as String,
      saticiId: j['seller_id'] as String,
      tur: j['tur'] as String,
      cins: j['cins'] as String,
      cinsiyet: j['cinsiyet'] as String,
      adet: (j['adet'] as num).toInt(),
      yasMin: (j['yas_min'] as num).toInt(),
      yasMax: (j['yas_max'] as num).toInt(),
      agirlik: (j['agirlik_kg'] as num).toDouble(),
      toplam: (j['toplam_fiyat'] as num).toDouble(),
      satisSekli: j['satis_sekli'] as String? ?? 'birlikte',
      il: j['il'] as String,
      ilce: j['ilce'] as String,
      durum: j['durum'] as String? ?? 'aktif',
      aciklama: j['aciklama'] as String?,
      olusturma: DateTime.parse(j['created_at'] as String),
      mesafe: mesafe,
      satildiAt: j['satildi_at'] == null ? null : DateTime.parse(j['satildi_at'] as String),
      bitis: j['expires_at'] == null ? null : DateTime.parse(j['expires_at'] as String),
      videoYol: j['video_path'] as String?,
      amac: j['amac'] as String?,
      belgeler: ((j['belgeler'] as List?) ?? const []).map((e) => '$e').toList(),
      pazarlik: j['pazarlik'] as bool? ?? false,
      teslimat: j['teslimat'] as String? ?? 'yerinde',
      goruntulenme: (j['goruntulenme'] as num?)?.toInt() ?? 0,
      moderasyon: j['moderasyon'] as String?,
      moderasyonNeden: j['moderasyon_neden'] as String?,
      saticiAd: sAd ?? 'Satıcı',
      saticiPuan: (sPuan ?? 0).toDouble(),
      saticiPuanSayisi: sSayi ?? 0,
    );
  }
}

class AktifEtiket {
  AktifEtiket(this.metin, this.alanlar);
  final String metin;
  final List<String> alanlar;
}

class Filtre {
  static const varsayilan = <String, String>{
    'tur': 'Hepsi',
    'cins': '',
    'satis': 'Hepsi',
    'adetMin': '',
    'adetMax': '',
    'yasMin': '',
    'yasMax': '',
    'kgMin': '',
    'kgMax': '',
    'fiyatMin': '',
    'fiyatMax': '',
    'il': '',
    'mesafe': '',
    'amac': 'Hepsi',
    'belgeler': '',
    'sirala': 'En yeni',
  };
  static const siralamalar = ['En yeni', 'En yakın', 'Fiyat: artan', 'Fiyat: azalan'];
  static const mesafeler = {'': 'Sadece burası', '50': '50 km', '100': '100 km', '200': '200 km'};

  /// "En yakın" sıralaması ve mesafe filtresi için merkez (filtredeki konum, yoksa profil konumu).
  static ({double lat, double lng})? Function()? profilKonumu;

  Filtre([Map<String, String>? m]) : v = {...varsayilan, ...?m};
  factory Filtre.json(dynamic j) {
    final m = <String, String>{};
    if (j is Map) j.forEach((k, x) => m['$k'] = '$x');
    return Filtre(m);
  }

  final Map<String, String> v;
  Filtre kopya() => Filtre(Map.of(v));
  String operator [](String k) => v[k] ?? '';
  void operator []=(String k, String x) => v[k] = x;
  void sifirla(List<String> k) {
    for (final a in k) {
      v[a] = varsayilan[a] ?? '';
    }
  }

  void hepsiniTemizle() {
    v
      ..clear()
      ..addAll(varsayilan);
  }

  List<String> get belgeSecili => this['belgeler'].isEmpty ? <String>[] : this['belgeler'].split(',');

  void belgeDegistir(String kod) {
    final l = belgeSecili;
    l.contains(kod) ? l.remove(kod) : l.add(kod);
    this['belgeler'] = l.join(',');
  }

  String get imza => jsonEncode(v);

  String _aralik(String a, String b) => '${this[a].isEmpty ? '…' : this[a]} – ${this[b].isEmpty ? '…' : this[b]}';

  List<AktifEtiket> aktif() {
    final o = <AktifEtiket>[];
    if (this['cins'].isNotEmpty) o.add(AktifEtiket(this['cins'], ['cins']));
    if (this['satis'] != 'Hepsi') o.add(AktifEtiket(this['satis'], ['satis']));
    if (this['adetMin'].isNotEmpty || this['adetMax'].isNotEmpty) {
      o.add(AktifEtiket('${_aralik('adetMin', 'adetMax')} baş', ['adetMin', 'adetMax']));
    }
    if (this['yasMin'].isNotEmpty || this['yasMax'].isNotEmpty) {
      o.add(AktifEtiket('${_aralik('yasMin', 'yasMax')} ay', ['yasMin', 'yasMax']));
    }
    if (this['kgMin'].isNotEmpty || this['kgMax'].isNotEmpty) {
      o.add(AktifEtiket('${_aralik('kgMin', 'kgMax')} kg', ['kgMin', 'kgMax']));
    }
    if (this['fiyatMin'].isNotEmpty || this['fiyatMax'].isNotEmpty) {
      o.add(AktifEtiket('${_aralik('fiyatMin', 'fiyatMax')} ₺', ['fiyatMin', 'fiyatMax']));
    }
    if (this['il'].isNotEmpty) o.add(AktifEtiket(this['mesafe'].isEmpty ? this['il'] : '${this['il']} · ${this['mesafe']} km', ['il', 'mesafe']));
    if (this['amac'] != 'Hepsi') o.add(AktifEtiket(this['amac'], ['amac']));
    if (belgeSecili.isNotEmpty) o.add(AktifEtiket(belgeSecili.map((k) => belgeEtiket[k] ?? k).join(' + '), ['belgeler']));
    return o;
  }

  Map<String, dynamic> rpc(String q) {
    final p = <String, dynamic>{'p_limit': 50};
    if (q.trim().isNotEmpty) p['p_q'] = q.trim();
    if (this['tur'] != 'Hepsi') p['p_tur'] = turKod[this['tur']];
    if (this['cins'].trim().isNotEmpty) p['p_cins'] = this['cins'].trim();
    if (this['satis'] == 'Tek hayvan') p['p_sale'] = 'tek';
    if (this['satis'] == 'Sürü') p['p_sale'] = 'suru';
    void n(String k, String pk, {bool tam = false}) {
      final x = sayiOku(this[k]);
      if (x != null) p[pk] = tam ? x.round() : x;
    }

    n('adetMin', 'p_adet_min', tam: true);
    n('adetMax', 'p_adet_max', tam: true);
    n('yasMin', 'p_yas_min', tam: true);
    n('yasMax', 'p_yas_max', tam: true);
    n('kgMin', 'p_kg_min');
    n('kgMax', 'p_kg_max');
    n('fiyatMin', 'p_fiyat_min');
    n('fiyatMax', 'p_fiyat_max');
    final yer = konumCoz(this['il']);
    final merkez = yer == null ? null : konumu(yer.il, yer.ilce);
    if (this['il'].trim().isNotEmpty) {
      if (merkez != null && this['mesafe'].isNotEmpty) {
        p['p_lat'] = merkez.lat;
        p['p_lng'] = merkez.lng;
        p['p_radius_km'] = int.tryParse(this['mesafe']) ?? 100;
      } else {
        p['p_il'] = yer == null ? this['il'].trim() : (yer.ilce ?? yer.il);
      }
    }
    if (this['sirala'] == 'En yakın' && !p.containsKey('p_lat')) {
      final m = merkez ?? profilKonumu?.call();
      if (m != null) {
        p['p_lat'] = m.lat;
        p['p_lng'] = m.lng;
      }
    }
    if (this['amac'] != 'Hepsi') p['p_amac'] = amacKod[this['amac']];
    if (belgeSecili.isNotEmpty) p['p_belgeler'] = belgeSecili;
    p['p_sort'] = switch (this['sirala']) {
      'Fiyat: artan' => 'fiyat_artan',
      'Fiyat: azalan' => 'fiyat_azalan',
      'En yakın' => 'en_yakin',
      _ => 'en_yeni',
    };
    return p;
  }
}

class Mesaj {
  Mesaj({required this.id, required this.gonderen, required this.metin, required this.zaman, this.okundu, this.tur = 'metin', this.tutar, this.yanit});
  final String id, gonderen, metin;
  final DateTime zaman;
  final DateTime? okundu;

  /// metin | teklif | teklif_yanit (010)
  final String tur;
  final double? tutar;

  /// Teklif için: kabul | red | null (yanıt bekliyor)
  final String? yanit;
  bool get teklif => tur == 'teklif' && tutar != null;
  factory Mesaj.json(Map<String, dynamic> j) => Mesaj(
        id: j['id'] as String,
        gonderen: j['sender_id'] as String,
        metin: j['body'] as String,
        zaman: DateTime.parse(j['created_at'] as String),
        okundu: j['read_at'] == null ? null : DateTime.parse(j['read_at'] as String),
        tur: j['tur'] as String? ?? 'metin',
        tutar: (j['tutar'] as num?)?.toDouble(),
        yanit: j['yanit'] as String?,
      );
}

class Konusma {
  Konusma({
    required this.id,
    required this.ilanId,
    required this.karsiId,
    required this.karsiAd,
    required this.alici,
    this.ilanCins,
    this.ilanAdet,
    this.ilanFiyat,
  });
  final String id, ilanId, karsiId, karsiAd;
  final bool alici; // ben alıcı mıyım
  final String? ilanCins;
  final int? ilanAdet;
  final num? ilanFiyat;
  Mesaj? son;
  int okunmamis = 0;

  String get bas => karsiAd.isEmpty ? '?' : karsiAd.substring(0, 1).toUpperCase();

  factory Konusma.json(Map<String, dynamic> j, String ben) {
    final alici = j['buyer_id'] == ben;
    final karsi = (alici ? j['seller'] : j['buyer']) as Map?;
    final l = j['listing'] as Map?;
    return Konusma(
      id: j['id'] as String,
      ilanId: j['listing_id'] as String,
      karsiId: (alici ? j['seller_id'] : j['buyer_id']) as String,
      karsiAd: (karsi?['full_name'] as String?) ?? 'Kullanıcı',
      alici: alici,
      ilanCins: l?['cins'] as String?,
      ilanAdet: (l?['adet'] as num?)?.toInt(),
      ilanFiyat: l?['toplam_fiyat'] as num?,
    );
  }
}

/// Alıcı talebi: "şunu arıyorum" ilanı.
class Talep {
  Talep({
    required this.id,
    required this.aliciId,
    required this.tur,
    required this.adet,
    required this.il,
    required this.durum,
    required this.olusturma,
    this.cins,
    this.amac,
    this.butce,
    this.aciklama,
    this.aliciAd = 'Alıcı',
  });

  final String id, aliciId, tur, il, durum;
  final String? cins, amac, aciklama;
  final int adet;
  final double? butce;
  final DateTime olusturma;
  final String aliciAd;

  String get turAd => turEtiket[tur] ?? tur;
  String? get amacAd => amac == null ? null : amacEtiket[amac];
  String get baslik => '${cins ?? turAd} arıyorum';
  bool get aktif => durum == 'aktif';

  factory Talep.json(Map<String, dynamic> j) {
    final a = j['buyer'];
    return Talep(
      id: j['id'] as String,
      aliciId: j['buyer_id'] as String,
      tur: j['tur'] as String,
      cins: j['cins'] as String?,
      adet: (j['adet'] as num).toInt(),
      amac: j['amac'] as String?,
      butce: (j['butce_max'] as num?)?.toDouble(),
      il: j['il'] as String,
      aciklama: j['aciklama'] as String?,
      durum: j['durum'] as String? ?? 'aktif',
      olusturma: DateTime.parse(j['created_at'] as String),
      aliciAd: (a is Map ? a['full_name'] as String? : null) ?? 'Alıcı',
    );
  }
}

/// Yönetici paneli sayıları (yonetici_ozet RPC'sinin döndürdüğü JSON).
class YoneticiOzet {
  YoneticiOzet(this.ham);
  final Map<String, dynamic> ham;

  Map<String, dynamic> _grup(String g) => (ham[g] as Map?)?.cast<String, dynamic>() ?? const {};

  /// Örn. n('ilanlar', 'aktif')
  int n(String grup, String alan) => ((_grup(grup)[alan] as num?) ?? 0).toInt();

  /// Örn. dagilim('ilanlar', 'tur') → {'kucukbas': 3}
  Map<String, int> dagilim(String grup, String alan) =>
      ((_grup(grup)[alan] as Map?) ?? const {}).map((k, v) => MapEntry('$k', (v as num).toInt()));

  List<({String il, int n})> get iller => [
        for (final e in ((_grup('ilanlar')['il'] as List?) ?? const []))
          (il: '${(e as Map)['il']}', n: ((e['n'] as num?) ?? 0).toInt()),
      ];

  /// Son 14 gün: tarih + cihaz/üye/ilan sayıları (eskiden yeniye).
  List<({DateTime gun, int cihaz, int uye, int ilan})> get gunluk => [
        for (final e in ((ham['gunluk'] as List?) ?? const []))
          (
            gun: DateTime.parse('${(e as Map)['gun']}'),
            cihaz: ((e['cihaz'] as num?) ?? 0).toInt(),
            uye: ((e['uye'] as num?) ?? 0).toInt(),
            ilan: ((e['ilan'] as num?) ?? 0).toInt(),
          ),
      ];

  DateTime? get olusturma => DateTime.tryParse('${ham['olusturma']}')?.toLocal();

  /// 009 moderasyon sayıları (yoksa null).
  Map<String, dynamic>? get moderasyon => (ham['moderasyon'] as Map?)?.cast<String, dynamic>();
}
