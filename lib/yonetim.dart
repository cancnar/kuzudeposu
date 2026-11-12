import 'data.dart';
import 'models.dart';

/// Yönetici paneli veri kaynağı. Gerçekte Supabase RPC'leri (008, 009);
/// testlerde ve yerel önizlemede [OrnekKaynak] (bellekte, işlemler gerçekten uygulanır).
abstract class YoneticiKaynak {
  Future<YoneticiOzet> ozet();
  Future<List<YSikayet>> sikayetler(String durum);
  Future<void> sikayetDurum(String id, String durum);

  /// filtre: onay | otomatik | gizli | supheli | tumu
  Future<List<YIlan>> ilanlar(String filtre, {String? ara});
  Future<void> ilanIslem(String id, String islem, {String? neden});
  Future<List<YKullanici>> kullanicilar({String? ara, bool sadeceAskida = false});
  Future<YKullanici> kullanici(String id);
  Future<void> askiyaAl(String id, bool askida, {String? neden});
  Future<void> ayar(String anahtar, Object deger);
}

YoneticiKaynak yonetim = RpcKaynak();

const sikayetEtiket = {
  'baska_hayvan_fotografi': 'Başka hayvanın fotoğrafı',
  'sahte_ilan': 'Sahte ilan',
  'kapora_istiyor': 'Kapora / ön ödeme istiyor',
  'uygunsuz_mesaj': 'Uygunsuz mesaj',
  'diger': 'Diğer',
};

class YIlan {
  YIlan({required this.ilan, this.foto, this.nedenler = const [], this.sikayet = 0, this.saticiAskida = false});
  final Ilan ilan;
  final String? foto;
  final List<String> nedenler;
  final int sikayet;
  final bool saticiAskida;

  factory YIlan.json(Map<String, dynamic> j) {
    final s = (j['satici'] as Map?) ?? const {};
    final f = j['foto'] as String?;
    return YIlan(
      ilan: Ilan.json((j['ilan'] as Map).cast<String, dynamic>(), ad: s['ad'] as String?),
      foto: f == null ? null : fotoUrl(f),
      nedenler: ((j['nedenler'] as List?) ?? const []).map((e) => '$e').toList(),
      sikayet: ((j['sikayet'] as num?) ?? 0).toInt(),
      saticiAskida: s['askida'] == true,
    );
  }
}

class YSikayet {
  YSikayet({
    required this.id,
    required this.sebep,
    required this.durum,
    required this.tarih,
    this.detay,
    this.bildiren,
    this.ilan,
    this.kullaniciId,
    this.kullaniciAd,
    this.ayniIlan = 0,
  });
  final String id, sebep, durum;
  final DateTime tarih;
  final String? detay, bildiren, kullaniciId, kullaniciAd;
  final YIlan? ilan;
  final int ayniIlan;
  String get sebepAd => sikayetEtiket[sebep] ?? sebep;

  factory YSikayet.json(Map<String, dynamic> j) {
    final k = j['kullanici'] as Map?;
    final il = j['ilan'] as Map?;
    return YSikayet(
      id: j['id'] as String,
      sebep: j['reason'] as String,
      durum: j['status'] as String,
      tarih: DateTime.parse(j['created_at'] as String),
      detay: (j['detail'] as String?)?.trim().isEmpty ?? true ? null : j['detail'] as String,
      bildiren: (j['bildiren'] as Map?)?['ad'] as String?,
      ilan: il == null ? null : YIlan.json(il.cast<String, dynamic>()),
      kullaniciId: k?['id'] as String?,
      kullaniciAd: k?['ad'] as String?,
      ayniIlan: ((j['ayni_ilan'] as num?) ?? 0).toInt(),
    );
  }
}

class YKullanici {
  YKullanici({
    required this.id,
    required this.ad,
    required this.il,
    required this.ilce,
    required this.rol,
    required this.kayit,
    this.telefon,
    this.askida = false,
    this.askidaNeden,
    this.yonetici = false,
    this.ornek = false,
    this.ilanAktif = 0,
    this.ilanToplam = 0,
    this.satildi = 0,
    this.mesaj = 0,
    this.talep = 0,
    this.sikayet = 0,
    this.sikayetToplam = 0,
    this.puan = 0,
    this.puanSayisi = 0,
    this.sikayetler = const [],
    this.ilanlar = const [],
  });
  final String id, ad, il, ilce, rol;
  final DateTime kayit;
  final String? telefon, askidaNeden;
  final bool askida, yonetici, ornek;
  final int ilanAktif, ilanToplam, satildi, mesaj, talep, sikayet, sikayetToplam, puanSayisi;
  final double puan;
  final List<YSikayet> sikayetler;
  final List<YIlan> ilanlar;
  String get rolAd => const {'yetistirici': 'Yetiştirici', 'tuccar': 'Tüccar', 'alici': 'Alıcı'}[rol] ?? rol;

  factory YKullanici.json(Map<String, dynamic> j) {
    int n(String k) => ((j[k] as num?) ?? 0).toInt();
    return YKullanici(
      id: j['id'] as String,
      ad: j['ad'] as String? ?? '',
      il: j['il'] as String? ?? '',
      ilce: j['ilce'] as String? ?? '',
      rol: j['rol'] as String? ?? '',
      kayit: DateTime.parse(j['created_at'] as String),
      telefon: j['telefon'] as String?,
      askida: j['askida'] == true,
      askidaNeden: j['askida_neden'] as String?,
      yonetici: j['yonetici'] == true,
      ornek: j['ornek'] == true,
      ilanAktif: n('ilan_aktif'),
      ilanToplam: n('ilan_toplam'),
      satildi: n('satildi'),
      mesaj: n('mesaj'),
      talep: n('talep'),
      sikayet: n('sikayet'),
      sikayetToplam: n('sikayet_toplam'),
      puan: ((j['puan'] as num?) ?? 0).toDouble(),
      puanSayisi: n('puan_sayisi'),
      sikayetler: [
        for (final s in ((j['sikayetler'] as List?) ?? const []))
          YSikayet(
            id: (s as Map)['id'] as String,
            sebep: s['reason'] as String,
            durum: s['status'] as String,
            tarih: DateTime.parse(s['created_at'] as String),
            detay: s['detail'] as String?,
            bildiren: s['bildiren'] as String?,
            kullaniciAd: s['ilan'] as String?,
          ),
      ],
      ilanlar: [for (final x in ((j['ilanlar'] as List?) ?? const [])) YIlan.json((x as Map).cast<String, dynamic>())],
    );
  }
}

List<Map<String, dynamic>> _liste(dynamic r) => [for (final x in (r as List? ?? const [])) (x as Map).cast<String, dynamic>()];

class RpcKaynak implements YoneticiKaynak {
  @override
  Future<YoneticiOzet> ozet() async {
    final o = await yoneticiOzet();
    try {
      o.ham['moderasyon'] = Map<String, dynamic>.from(await db.rpc('yonetici_moderasyon_ozet') as Map);
    } catch (_) {
      // 009_moderasyon.sql henüz çalıştırılmamış: panel moderasyon bölümünde uyarı gösterir.
    }
    return o;
  }

  @override
  Future<List<YSikayet>> sikayetler(String durum) async =>
      _liste(await db.rpc('yonetici_sikayetler', params: {'p_durum': durum})).map(YSikayet.json).toList();

  @override
  Future<void> sikayetDurum(String id, String durum) => db.rpc('yonetici_sikayet_durum', params: {'p_id': id, 'p_durum': durum});

  @override
  Future<List<YIlan>> ilanlar(String filtre, {String? ara}) async =>
      _liste(await db.rpc('yonetici_ilanlar', params: {'p_filtre': filtre, 'p_ara': ara})).map(YIlan.json).toList();

  @override
  Future<void> ilanIslem(String id, String islem, {String? neden}) =>
      db.rpc('yonetici_ilan_islem', params: {'p_id': id, 'p_islem': islem, 'p_neden': neden});

  @override
  Future<List<YKullanici>> kullanicilar({String? ara, bool sadeceAskida = false}) async =>
      _liste(await db.rpc('yonetici_kullanicilar', params: {'p_ara': ara, 'p_sadece_askida': sadeceAskida})).map(YKullanici.json).toList();

  @override
  Future<YKullanici> kullanici(String id) async =>
      YKullanici.json(Map<String, dynamic>.from(await db.rpc('yonetici_kullanici', params: {'p_id': id}) as Map));

  @override
  Future<void> askiyaAl(String id, bool askida, {String? neden}) =>
      db.rpc('yonetici_askiya_al', params: {'p_id': id, 'p_askida': askida, 'p_neden': neden});

  @override
  Future<void> ayar(String anahtar, Object deger) => db.rpc('yonetici_ayar', params: {'p_anahtar': anahtar, 'p_deger': deger});
}

/// Örnek veri: widget testleri ve yerel önizleme (localhost/?onizleme=yonetici). Gerçek kişi/veri değildir.
class OrnekKaynak implements YoneticiKaynak {
  OrnekKaynak() {
    final simdi = DateTime.now();
    Ilan ilan(String id, String saticiId, String ad, String tur, String cins, int adet, double kg, double fiyat, String il, String ilce,
            {String durum = 'aktif', String? mod, String? aciklama, int gun = 1}) =>
        Ilan(
          id: id,
          saticiId: saticiId,
          tur: tur,
          cins: cins,
          cinsiyet: 'erkek',
          adet: adet,
          yasMin: 10,
          yasMax: adet > 1 ? 14 : 10,
          agirlik: kg,
          toplam: fiyat,
          satisSekli: 'birlikte',
          il: il,
          ilce: ilce,
          durum: durum,
          moderasyon: mod,
          aciklama: aciklama,
          olusturma: simdi.subtract(Duration(days: gun)),
          saticiAd: ad,
        );
    _kisiler.addAll([
      YKullanici(id: 'k1', ad: 'Sabri Kaya', il: 'Manisa', ilce: 'Kula', rol: 'tuccar', kayit: simdi.subtract(const Duration(days: 40)),
          telefon: '905442223344', ilanAktif: 1, ilanToplam: 4, satildi: 2, mesaj: 31, sikayet: 3, sikayetToplam: 4, puan: 3.1, puanSayisi: 7),
      YKullanici(id: 'k2', ad: 'Hatice Demir', il: 'Konya', ilce: 'Karatay', rol: 'yetistirici', kayit: simdi.subtract(const Duration(days: 12)),
          telefon: '905061112233', ilanAktif: 3, ilanToplam: 3, mesaj: 12, puan: 4.9, puanSayisi: 11),
      YKullanici(id: 'k3', ad: 'Mustafa Koç', il: 'İzmir', ilce: 'Bornova', rol: 'alici', kayit: simdi.subtract(const Duration(days: 3)),
          telefon: '905339876543', mesaj: 4, talep: 1),
      YKullanici(id: 'k4', ad: 'Recep Arslan', il: 'Afyonkarahisar', ilce: 'Merkez', rol: 'tuccar', kayit: simdi.subtract(const Duration(days: 60)),
          telefon: '905551234567', askida: true, askidaNeden: 'Kapora isteyerek dolandırıcılık', ilanToplam: 5, sikayetToplam: 6),
    ]);
    _ilanlar.addAll([
      YIlan(
        ilan: ilan('i1', 'k1', 'Sabri Kaya', 'buyukbas', 'Holstein düve', 1, 550, 60000, 'Manisa', 'Kula',
            aciklama: 'Acil satılık. Kaporayı IBAN\'a atın, 0532 111 22 33 arayın.'),
        nedenler: ['IBAN', 'Telefon numarası', 'Kapora / ön ödeme', 'Piyasanın yarısından ucuz'],
        sikayet: 2,
      ),
      YIlan(
        ilan: ilan('i2', 'k1', 'Sabri Kaya', 'kucukbas', 'Merinos koç', 1, 80, 30000, 'Manisa', 'Kula', durum: 'pasif', mod: 'otomatik_gizlendi', gun: 2),
        sikayet: 3,
      ),
      YIlan(ilan: ilan('i3', 'k2', 'Hatice Demir', 'kucukbas', 'Kıvırcık kuzu', 12, 42, 210000, 'Konya', 'Karatay', durum: 'pasif', mod: 'onay_bekliyor', gun: 0)),
      YIlan(
        ilan: ilan('i4', 'k2', 'Hatice Demir', 'kucukbas', 'Akkaraman toklu', 20, 55, 440000, 'Konya', 'Karatay', aciklama: 'Ödemeyi havale ile alırım.', gun: 4),
        nedenler: ['Kapora / ön ödeme'],
      ),
      YIlan(
        ilan: ilan('i5', 'k4', 'Recep Arslan', 'buyukbas', 'Simental tosun', 1, 610, 260000, 'Afyonkarahisar', 'Merkez',
            durum: 'pasif', mod: 'hesap_askida', gun: 20),
        saticiAskida: true,
      ),
    ]);
    _sikayetler.addAll([
      YSikayet(id: 's1', sebep: 'kapora_istiyor', durum: 'yeni', tarih: simdi.subtract(const Duration(minutes: 25)),
          detay: 'Hayvanı görmeden 5.000 TL kapora istedi.', bildiren: 'Mustafa Koç', ilan: _ilanlar[0], kullaniciId: 'k1', kullaniciAd: 'Sabri Kaya', ayniIlan: 2),
      YSikayet(id: 's2', sebep: 'baska_hayvan_fotografi', durum: 'yeni', tarih: simdi.subtract(const Duration(hours: 3)),
          bildiren: 'Ayşe Tekin', ilan: _ilanlar[0], ayniIlan: 2),
      YSikayet(id: 's3', sebep: 'uygunsuz_mesaj', durum: 'yeni', tarih: simdi.subtract(const Duration(days: 1)),
          detay: 'Mesajda hakaret etti.', bildiren: 'Hatice Demir', kullaniciId: 'k1', kullaniciAd: 'Sabri Kaya'),
      YSikayet(id: 's4', sebep: 'sahte_ilan', durum: 'inceleniyor', tarih: simdi.subtract(const Duration(days: 2)),
          bildiren: 'Mustafa Koç', ilan: _ilanlar[1], ayniIlan: 3),
    ]);
  }

  final _kisiler = <YKullanici>[];
  final _ilanlar = <YIlan>[];
  final _sikayetler = <YSikayet>[];
  bool _onOnay = false;

  Future<T> _bekle<T>(T Function() f) => Future<T>.delayed(const Duration(milliseconds: 150), f);

  bool _supheli(YIlan y) => y.nedenler.isNotEmpty && (y.ilan.aktif || y.ilan.moderasyon == 'onay_bekliyor');

  @override
  Future<YoneticiOzet> ozet() => _bekle(() {
        final o = YoneticiOzet(Map<String, dynamic>.from(onizlemeOzeti));
        o.ham['moderasyon'] = {
          'sikayet_yeni': _sikayetler.where((s) => s.durum == 'yeni').length,
          'sikayet_inceleniyor': _sikayetler.where((s) => s.durum == 'inceleniyor').length,
          'onay_bekleyen': _ilanlar.where((y) => y.ilan.moderasyon == 'onay_bekliyor').length,
          'otomatik_gizlenen': _ilanlar.where((y) => y.ilan.moderasyon == 'otomatik_gizlendi').length,
          'supheli': _ilanlar.where(_supheli).length,
          'askida_kullanici': _kisiler.where((k) => k.askida).length,
          'on_onay': _onOnay,
        };
        return o;
      });

  @override
  Future<List<YSikayet>> sikayetler(String durum) => _bekle(() => _sikayetler.where((s) => s.durum == durum).toList());

  @override
  Future<void> sikayetDurum(String id, String durum) => _bekle(() {
        final i = _sikayetler.indexWhere((s) => s.id == id);
        final s = _sikayetler[i];
        _sikayetler[i] = YSikayet(
            id: s.id, sebep: s.sebep, durum: durum, tarih: s.tarih, detay: s.detay, bildiren: s.bildiren,
            ilan: s.ilan, kullaniciId: s.kullaniciId, kullaniciAd: s.kullaniciAd, ayniIlan: s.ayniIlan);
      });

  @override
  Future<List<YIlan>> ilanlar(String filtre, {String? ara}) => _bekle(() => _ilanlar.where((y) {
        final m = y.ilan.moderasyon;
        return switch (filtre) {
          'onay' => m == 'onay_bekliyor',
          'otomatik' => m == 'otomatik_gizlendi',
          'gizli' => m == 'yonetici_gizledi' || m == 'yonetici_kaldirdi' || m == 'hesap_askida',
          'supheli' => _supheli(y),
          _ => ara == null || ara.isEmpty || '${y.ilan.cins} ${y.ilan.il} ${y.ilan.saticiAd}'.toLowerCase().contains(ara.toLowerCase()),
        };
      }).toList());

  @override
  Future<void> ilanIslem(String id, String islem, {String? neden}) => _bekle(() {
        final i = _ilanlar.indexWhere((y) => y.ilan.id == id);
        final y = _ilanlar[i];
        final (String durum, String? mod) = switch (islem) {
          'onayla' || 'yayina_al' => ('aktif', null),
          'gizle' => ('pasif', 'yonetici_gizledi'),
          _ => ('kaldirildi', 'yonetici_kaldirdi'),
        };
        final l = y.ilan;
        _ilanlar[i] = YIlan(
          ilan: Ilan(
            id: l.id, saticiId: l.saticiId, tur: l.tur, cins: l.cins, cinsiyet: l.cinsiyet, adet: l.adet, yasMin: l.yasMin, yasMax: l.yasMax,
            agirlik: l.agirlik, toplam: l.toplam, satisSekli: l.satisSekli, il: l.il, ilce: l.ilce, durum: durum, olusturma: l.olusturma,
            aciklama: l.aciklama, moderasyon: mod, moderasyonNeden: neden, saticiAd: l.saticiAd,
          ),
          foto: y.foto,
          nedenler: y.nedenler,
          saticiAskida: y.saticiAskida,
        );
        for (final s in _sikayetler.where((s) => s.ilan?.ilan.id == id).toList()) {
          final k = _sikayetler.indexOf(s);
          _sikayetler[k] = YSikayet(id: s.id, sebep: s.sebep, durum: 'kapandi', tarih: s.tarih, detay: s.detay, bildiren: s.bildiren,
              ilan: _ilanlar[i], kullaniciId: s.kullaniciId, kullaniciAd: s.kullaniciAd, ayniIlan: s.ayniIlan);
        }
      });

  @override
  Future<List<YKullanici>> kullanicilar({String? ara, bool sadeceAskida = false}) => _bekle(() => _kisiler.where((k) {
        if (sadeceAskida && !k.askida) return false;
        final q = (ara ?? '').trim().toLowerCase();
        if (q.isEmpty) return true;
        final rakam = q.replaceAll(RegExp(r'\D'), '');
        return k.ad.toLowerCase().contains(q) || (rakam.length >= 4 && (k.telefon ?? '').contains(rakam));
      }).toList());

  @override
  Future<YKullanici> kullanici(String id) => _bekle(() {
        final k = _kisiler.firstWhere((k) => k.id == id);
        return YKullanici(
          id: k.id, ad: k.ad, il: k.il, ilce: k.ilce, rol: k.rol, kayit: k.kayit, telefon: k.telefon, askida: k.askida,
          askidaNeden: k.askidaNeden, ilanAktif: k.ilanAktif, ilanToplam: k.ilanToplam, satildi: k.satildi, mesaj: k.mesaj, talep: k.talep,
          sikayet: k.sikayet, sikayetToplam: k.sikayetToplam, puan: k.puan, puanSayisi: k.puanSayisi,
          sikayetler: _sikayetler.where((s) => s.kullaniciId == id || s.ilan?.ilan.saticiId == id).toList(),
          ilanlar: _ilanlar.where((y) => y.ilan.saticiId == id).toList(),
        );
      });

  @override
  Future<void> askiyaAl(String id, bool askida, {String? neden}) => _bekle(() {
        final i = _kisiler.indexWhere((k) => k.id == id);
        final k = _kisiler[i];
        _kisiler[i] = YKullanici(
          id: k.id, ad: k.ad, il: k.il, ilce: k.ilce, rol: k.rol, kayit: k.kayit, telefon: k.telefon, askida: askida,
          askidaNeden: askida ? neden : null, ilanAktif: askida ? 0 : k.ilanAktif, ilanToplam: k.ilanToplam, satildi: k.satildi,
          mesaj: k.mesaj, talep: k.talep, sikayet: k.sikayet, sikayetToplam: k.sikayetToplam, puan: k.puan, puanSayisi: k.puanSayisi,
        );
      });

  @override
  Future<void> ayar(String anahtar, Object deger) => _bekle(() => _onOnay = deger == true);
}

/// Panelin genel sayıları için örnek veri (gerçek değildir).
final onizlemeOzeti = <String, dynamic>{
  'kullanim': {'toplam_cihaz': 1250, 'bugun': 140, 'son7': 610, 'son30': 1100, 'misafir_bugun': 52, 'platform': {'web': 700, 'ios': 250, 'android': 150}},
  'uyeler': {'toplam': 412, 'bugun': 9, 'son7': 61, 'son30': 230, 'kayitli_ama_profilsiz': 14, 'rol': {'yetistirici': 210, 'tuccar': 48, 'alici': 154}},
  'ilanlar': {
    'aktif': 87, 'toplam': 140, 'bugun': 4, 'son7': 31, 'satildi': 29, 'pasif': 6, 'suresi_doldu': 18, 'videolu': 12, 'goruntulenme': 15873,
    'ilan_veren': 73, 'ornek_aktif': 17, 'tur': {'kucukbas': 60, 'buyukbas': 22, 'at': 3, 'kanatli': 2},
    'il': [{'il': 'Manisa', 'n': 41}, {'il': 'Afyonkarahisar', 'n': 12}, {'il': 'İzmir', 'n': 9}],
  },
  'etkilesim': {'aktif_talep': 23, 'sohbet': 310, 'mesaj': 2480, 'mesaj_son7': 640, 'favori': 905, 'degerlendirme': 44, 'bekleyen_sikayet': 3},
  'gunluk': [for (var i = 0; i < 14; i++) {'gun': '2026-11-${(i + 1).toString().padLeft(2, '0')}', 'cihaz': 40 + i * 7 + (i == 13 ? 9 : 0), 'uye': i % 4, 'ilan': i % 3}],
  'olusturma': '2026-11-12T20:15:00+03:00',
};
