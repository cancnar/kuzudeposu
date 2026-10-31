import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

/// Testlerde gerçek istemci buraya atanır.
SupabaseClient? testIstemci;
SupabaseClient get db => testIstemci ?? Supabase.instance.client;
String? get uid => db.auth.currentUser?.id;

const _saticiEmbed = 'seller:profiles!seller_id(full_name,rating_avg,rating_count)';

String videoUrl(String yol) => db.storage.from('listing-videos').getPublicUrl(yol);

String videoTipi(String ad) {
  final uz = ad.contains('.') ? ad.split('.').last.toLowerCase() : 'mp4';
  return switch (uz) { 'mov' => 'video/quicktime', 'webm' => 'video/webm', _ => 'video/mp4' };
}

String fotoUrl(String yol) => db.storage.from('listing-photos').getPublicUrl(yol);

Future<void> fotolariDoldur(List<Ilan> liste) async {
  if (liste.isEmpty) return;
  final r = await db
      .from('listing_photos')
      .select('listing_id,path,sort_order')
      .inFilter('listing_id', liste.map((e) => e.id).toList())
      .order('sort_order');
  final harita = <String, List<String>>{};
  for (final x in r) {
    (harita[x['listing_id'] as String] ??= []).add(fotoUrl(x['path'] as String));
  }
  for (final i in liste) {
    i.foto = harita[i.id] ?? [];
  }
}

Future<List<Ilan>> ilanAra(String q, Filtre f) async {
  final r = (await db.rpc('search_listings', params: f.rpc(q))) as List<dynamic>;
  final liste = r.map((e) {
    final m = e as Map<String, dynamic>;
    return Ilan.json(
      m['listing'] as Map<String, dynamic>,
      ad: m['seller_name'] as String?,
      puan: m['seller_rating'] as num?,
      puanSayisi: (m['seller_rating_count'] as num?)?.toInt(),
      mesafe: (m['distance_km'] as num?)?.toDouble(),
    );
  }).toList();
  await fotolariDoldur(liste);
  return liste;
}

/// Aynı türdeki aktif ilanların kg fiyatı özeti (piyasa karşılaştırması).
class FiyatOzeti {
  FiyatOzeti(this.adet, this.medyan, this.enDusuk, this.enYuksek);
  final int adet;
  final double medyan, enDusuk, enYuksek;
}

Future<FiyatOzeti?> fiyatOzeti(Ilan i) async {
  final r = await db.rpc('fiyat_ozeti', params: {'p_tur': i.tur, 'p_cins': i.cins, 'p_haric': i.id});
  var l = r as List<dynamic>;
  var m = l.isEmpty ? null : l.first as Map<String, dynamic>;
  if (m == null || (m['adet'] as num) < 2) {
    final r2 = await db.rpc('fiyat_ozeti', params: {'p_tur': i.tur, 'p_haric': i.id});
    l = r2 as List<dynamic>;
    m = l.isEmpty ? null : l.first as Map<String, dynamic>;
  }
  if (m == null || (m['adet'] as num) < 2 || m['medyan'] == null) return null;
  return FiyatOzeti((m['adet'] as num).toInt(), (m['medyan'] as num).toDouble(), (m['en_dusuk'] as num).toDouble(), (m['en_yuksek'] as num).toDouble());
}

Future<void> ilanGoruntule(String id) async {
  try {
    await db.rpc('ilan_goruntule', params: {'p_id': id});
  } catch (_) {}
}

Future<Map<String, dynamic>?> ilanIstatistik(String id) async {
  final r = await db.rpc('ilan_istatistik', params: {'p_id': id}) as List<dynamic>;
  return r.isEmpty ? null : r.first as Map<String, dynamic>;
}

Future<Ilan?> ilanGetir(String id) async {
  final r = await db.from('listings').select('*, $_saticiEmbed').eq('id', id).maybeSingle();
  if (r == null) return null;
  final i = Ilan.json(r);
  await fotolariDoldur([i]);
  return i;
}

Future<List<Ilan>> benimIlanlarim() async {
  final r = await db.from('listings').select('*, $_saticiEmbed').eq('seller_id', uid!).order('created_at', ascending: false);
  final l = r.map((e) => Ilan.json(e)).toList();
  await fotolariDoldur(l);
  return l;
}

Future<List<Ilan>> favoriIlanlar() async {
  final r = await db
      .from('favorites')
      .select('listing:listings(*, $_saticiEmbed)')
      .eq('user_id', uid!)
      .order('created_at', ascending: false);
  final l = <Ilan>[];
  for (final x in r) {
    final m = x['listing'];
    if (m is Map<String, dynamic>) l.add(Ilan.json(m));
  }
  await fotolariDoldur(l);
  return l;
}

Future<Set<String>> favoriIdleri() async {
  final r = await db.from('favorites').select('listing_id').eq('user_id', uid!);
  return {for (final x in r) x['listing_id'] as String};
}

Future<void> favoriDegistir(String ilanId, bool ekle) async {
  if (ekle) {
    await db.from('favorites').insert({'user_id': uid, 'listing_id': ilanId});
  } else {
    await db.from('favorites').delete().eq('user_id', uid!).eq('listing_id', ilanId);
  }
}

class FotoDosya {
  FotoDosya(this.bytes, this.ad, this.tip);
  final Uint8List bytes;
  final String ad, tip;
}

Future<String> ilanVer(Map<String, dynamic> alanlar, List<FotoDosya> fotolar, {FotoDosya? video}) async {
  final yeni = await db.from('listings').insert(alanlar).select('id').single();
  final id = yeni['id'] as String;
  try {
    final satirlar = <Map<String, dynamic>>[];
    for (var i = 0; i < fotolar.length; i++) {
      final f = fotolar[i];
      final uz = f.ad.contains('.') ? f.ad.split('.').last.toLowerCase() : 'jpg';
      final yol = '${uid!}/$id/$i.$uz';
      await db.storage.from('listing-photos').uploadBinary(yol, f.bytes, fileOptions: FileOptions(contentType: f.tip, upsert: true));
      satirlar.add({'listing_id': id, 'path': yol, 'sort_order': i});
    }
    await db.from('listing_photos').insert(satirlar);
    if (video != null) {
      final uz = video.ad.contains('.') ? video.ad.split('.').last.toLowerCase() : 'mp4';
      final yol = '${uid!}/$id/video.$uz';
      await db.storage.from('listing-videos').uploadBinary(yol, video.bytes, fileOptions: FileOptions(contentType: videoTipi(video.ad), upsert: true));
      await db.from('listings').update({'video_path': yol}).eq('id', id);
    }
  } catch (e) {
    await db.from('listings').delete().eq('id', id);
    rethrow;
  }
  return id;
}

/// İlan süresini 30 gün uzatır (kalan süreye eklenir).
Future<void> ilanUzat(Ilan i) {
  final baz = (i.bitis != null && i.bitis!.isAfter(DateTime.now())) ? i.bitis! : DateTime.now();
  return db.from('listings').update({'expires_at': baz.add(const Duration(days: 30)).toUtc().toIso8601String()}).eq('id', i.id);
}

Future<void> ilanDurumu(String id, String durum) => db.from('listings').update({'durum': durum}).eq('id', id);

// ---- Mesajlaşma ----
const _konSecim =
    'id, listing_id, buyer_id, seller_id, listing:listings(id,cins,adet,toplam_fiyat), buyer:profiles!buyer_id(full_name), seller:profiles!seller_id(full_name)';

Future<List<Konusma>> konusmalar() async {
  final ben = uid!;
  final r = await db.from('conversations').select(_konSecim).or('buyer_id.eq.$ben,seller_id.eq.$ben');
  final liste = r.map((e) => Konusma.json(e, ben)).toList();
  if (liste.isEmpty) return liste;
  final mesajlar = await db
      .from('messages')
      .select()
      .inFilter('conversation_id', liste.map((e) => e.id).toList())
      .order('created_at', ascending: false)
      .limit(500);
  final harita = {for (final k in liste) k.id: k};
  for (final m in mesajlar) {
    final k = harita[m['conversation_id'] as String];
    if (k == null) continue;
    final ms = Mesaj.json(m);
    k.son ??= ms;
    if (ms.gonderen != ben && ms.okundu == null) k.okunmamis++;
  }
  liste.sort((a, b) {
    final x = a.son?.zaman ?? DateTime.fromMillisecondsSinceEpoch(0);
    final y = b.son?.zaman ?? DateTime.fromMillisecondsSinceEpoch(0);
    return y.compareTo(x);
  });
  return liste;
}

Future<Konusma?> konusmaGetir(String id) async {
  final r = await db.from('conversations').select(_konSecim).eq('id', id).maybeSingle();
  if (r == null) return null;
  return Konusma.json(r, uid!);
}

Future<String> konusmaAc(Ilan ilan) async {
  final ben = uid!;
  final var1 = await db.from('conversations').select('id').eq('listing_id', ilan.id).eq('buyer_id', ben).maybeSingle();
  if (var1 != null) return var1['id'] as String;
  final y = await db
      .from('conversations')
      .insert({'listing_id': ilan.id, 'buyer_id': ben, 'seller_id': ilan.saticiId})
      .select('id')
      .single();
  return y['id'] as String;
}

Future<void> mesajGonder(String konusmaId, String metin) =>
    db.from('messages').insert({'conversation_id': konusmaId, 'sender_id': uid, 'body': metin});

Future<void> okunduIsaretle(String konusmaId) => db
    .from('messages')
    .update({'read_at': DateTime.now().toUtc().toIso8601String()})
    .eq('conversation_id', konusmaId)
    .neq('sender_id', uid!)
    .isFilter('read_at', null);

Future<int> okunmamisMesajSayisi() async {
  final r = await db.from('messages').select('id').isFilter('read_at', null).neq('sender_id', uid!);
  return r.length;
}

// ---- Bildirim ----
Future<int> okunmamisBildirimSayisi() async {
  final r = await db.from('notifications').select('id').isFilter('read_at', null);
  return r.length;
}

Future<List<Map<String, dynamic>>> bildirimler() =>
    db.from('notifications').select().order('created_at', ascending: false).limit(50);

Future<void> bildirimOkundu(String id) =>
    db.from('notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('id', id);

Future<void> hepsiniOkundu() =>
    db.from('notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).isFilter('read_at', null);

// ---- Yorum, şikayet, engel ----
Future<List<Map<String, dynamic>>> yorumlar(String saticiId) => db
    .from('reviews')
    .select('rating,comment,created_at,reviewer:profiles!reviewer_id(full_name)')
    .eq('seller_id', saticiId)
    .order('created_at', ascending: false)
    .limit(100);

Future<void> yorumYaz(String konusmaId, String saticiId, int puan, String yorum) => db.from('reviews').insert({
      'conversation_id': konusmaId,
      'reviewer_id': uid,
      'seller_id': saticiId,
      'rating': puan,
      'comment': yorum.trim().isEmpty ? null : yorum.trim(),
    });

const sikayetSebepleri = {
  'İlandaki fotoğraf başka bir hayvana ait': 'baska_hayvan_fotografi',
  'Hayvan yok veya ilan sahte görünüyor': 'sahte_ilan',
  'Kapora veya ön ödeme istiyor': 'kapora_istiyor',
  'Uygunsuz veya tehditkâr mesaj': 'uygunsuz_mesaj',
  'Diğer': 'diger',
};

Future<void> sikayetEt({String? ilanId, String? kullaniciId, required String sebep, String? detay}) => db.from('reports').insert({
      'reporter_id': uid,
      'listing_id': ilanId,
      'reported_user_id': kullaniciId,
      'reason': sebep,
      'detail': (detay == null || detay.trim().isEmpty) ? null : detay.trim(),
    });

Future<void> engelle(String kisiId) => db.from('blocks').upsert({'blocker_id': uid, 'blocked_id': kisiId});
Future<void> engelKaldir(String kisiId) => db.from('blocks').delete().eq('blocker_id', uid!).eq('blocked_id', kisiId);

Future<List<Map<String, dynamic>>> engellenenler() =>
    db.from('blocks').select('blocked_id, kisi:profiles!blocked_id(full_name)').eq('blocker_id', uid!);

// ---- Kayıtlı aramalar ----
Future<List<Map<String, dynamic>>> kayitliAramalar() =>
    db.from('saved_searches').select().eq('user_id', uid!).order('created_at', ascending: false);

Future<void> aramaKaydet(String baslik, Filtre f) =>
    db.from('saved_searches').insert({'user_id': uid, 'title': baslik, 'filters': f.v, 'notify': true});

Future<void> aramaBildirim(String id, bool ac) => db.from('saved_searches').update({'notify': ac}).eq('id', id);
Future<void> aramaSil(String id) => db.from('saved_searches').delete().eq('id', id);

// ---- Herkese açık satıcı profili ----
Future<Map<String, dynamic>?> saticiProfil(String id) => db.from('profiles').select().eq('id', id).maybeSingle();

Future<int> saticiSatisSayisi(String id) async {
  final r = await db.from('listings').select('id').eq('seller_id', id).eq('durum', 'satildi');
  return r.length;
}

Future<List<Ilan>> saticiIlanlari(String id, String durum) async {
  final r = await db.from('listings').select('*, $_saticiEmbed').eq('seller_id', id).eq('durum', durum).order('created_at', ascending: false);
  final l = r.map((e) => Ilan.json(e)).toList();
  if (durum == 'satildi') {
    l.sort((a, b) => (b.satildiAt ?? b.olusturma).compareTo(a.satildiAt ?? a.olusturma));
  }
  await fotolariDoldur(l);
  return l;
}

// ---- Alıcı talepleri ----
const _talepSecim = '*, buyer:profiles!buyer_id(full_name)';

Future<List<Talep>> talepler({String? tur}) async {
  var q = db.from('wanted_ads').select(_talepSecim).eq('durum', 'aktif').gt('expires_at', DateTime.now().toUtc().toIso8601String());
  if (tur != null) q = q.eq('tur', tur);
  final r = await q.order('created_at', ascending: false).limit(50);
  return r.map((e) => Talep.json(e)).toList();
}

Future<List<Talep>> taleplerim() async {
  final r = await db.from('wanted_ads').select(_talepSecim).eq('buyer_id', uid!).order('created_at', ascending: false);
  return r.map((e) => Talep.json(e)).toList();
}

Future<String> talepVer(Map<String, dynamic> alanlar) async {
  final r = await db.from('wanted_ads').insert(alanlar).select('id').single();
  return r['id'] as String;
}

Future<void> talepKapat(String id) => db.from('wanted_ads').update({'durum': 'kapandi'}).eq('id', id);

/// Satıcı, kendi ilanını talebe önerir; sohbet id'si döner.
Future<String> talebeIlanOner(String talepId, String ilanId) async {
  final r = await db.rpc('talebe_ilan_oner', params: {'p_talep': talepId, 'p_ilan': ilanId});
  return r as String;
}
