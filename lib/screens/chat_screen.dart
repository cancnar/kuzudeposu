import 'package:flutter/material.dart';

import '../data.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'detail_screen.dart';
import 'report_screen.dart';
import 'satici_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.konusmaId});
  final String konusmaId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  Konusma? _k;
  Object? _hata;
  Stream<List<Map<String, dynamic>>>? _akis;
  final _mc = TextEditingController();
  bool _guvenli = true;
  int _okunmamisGorulen = -1;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final k = await konusmaGetir(widget.konusmaId);
      if (k == null) throw 'Konuşma bulunamadı.';
      _akis = db.from('messages').stream(primaryKey: ['id']).eq('conversation_id', widget.konusmaId).order('created_at', ascending: true);
      if (mounted) setState(() => _k = k);
      await okunduIsaretle(widget.konusmaId);
      app.sayaclariYenile();
    } catch (e) {
      if (mounted) setState(() => _hata = e);
    }
  }

  /// Gönderilmekte olan mesajlar: sunucudan dönene kadar saat simgesiyle hemen görünür,
  /// aynı metne ikinci kez basılırsa tekrar gönderilmez.
  final _bekleyen = <Mesaj>[];
  bool _saticiYazdi = false;
  var _yerelNo = 0;

  Future<void> _gonder([String? hazir]) async {
    final m = (hazir ?? _mc.text).trim();
    if (m.isEmpty || _bekleyen.any((x) => x.metin == m)) return;
    if (hazir == null) _mc.clear();
    final yerel = Mesaj(id: 'yerel-${_yerelNo++}', gonderen: uid ?? '', metin: m, zaman: DateTime.now());
    setState(() => _bekleyen.add(yerel));
    try {
      await mesajGonder(widget.konusmaId, m);
    } catch (e) {
      if (hazir == null && _mc.text.isEmpty) _mc.text = m;
      if (mounted) bildir(context, 'Mesaj gönderilemedi. Kullanıcı seni veya sen onu engellemiş olabilirsin.');
    } finally {
      // Akış yeni mesajı getirene kadar kısa bir süre daha göster (çift görünmeyi önler).
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _bekleyen.remove(yerel));
      });
    }
  }

  Future<void> _teklifYanit(Mesaj m, bool kabul) async {
    if (!kabul) {
      final ok = await onayIste(context, 'Teklif reddedilsin mi?', '${tl(m.tutar!)} teklifini reddettiğini karşı tarafa bildireceğiz.', 'Reddet', tehlike: true);
      if (!ok) return;
    }
    try {
      await teklifYanitla(m.id, kabul);
    } catch (e) {
      if (mounted) bildir(context, 'Yanıt gönderilemedi: $e');
    }
  }

  /// Teklif mesajı: tutar, istenen fiyata göre fark, karşı taraf için Kabul/Reddet.
  Widget _teklifKarti(Mesaj m, bool benim, double? istenen) {
    final t = m.tutar!;
    final fark = istenen == null || istenen <= 0 ? null : ((t - istenen) / istenen * 100).round();
    final durum = switch (m.yanit) { 'kabul' => 'Kabul edildi', 'red' => 'Reddedildi', _ => benim ? 'Yanıt bekleniyor' : null };
    return Align(
      alignment: benim ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .8),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Renk.kart,
          borderRadius: BorderRadius.circular(18),
          boxShadow: Golge.kart,
          border: Border.all(color: m.yanit == 'kabul' ? Renk.yesil : altin, width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.local_offer_outlined, size: 18, color: Renk.yesil),
            const SizedBox(width: 6),
            Text(benim ? 'Teklifin' : 'Teklif', style: const TextStyle(fontWeight: FontWeight.w800, color: Renk.soluk)),
          ]),
          const SizedBox(height: 4),
          Text(tl(t), style: baslik(26)),
          if (fark != null)
            Text(fark == 0 ? 'İstenen fiyatla aynı' : 'İstenen ${tl(istenen!)} · %${fark.abs()} ${fark < 0 ? 'altında' : 'üstünde'}',
                style: const TextStyle(color: Renk.soluk, fontSize: 13)),
          if (durum != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: m.yanit == 'kabul' ? Renk.okZemin : (m.yanit == 'red' ? const Color(0xFFF7E3DC) : Renk.zemin2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(durum,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: m.yanit == 'kabul' ? Renk.okYazi : (m.yanit == 'red' ? Renk.kiremit : Renk.murekkep))),
            ),
          ],
          if (!benim && m.yanit == null) ...[
            const SizedBox(height: 10),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Basma(child: FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(110, 44)), onPressed: () => _teklifYanit(m, true), child: const Text('Kabul et'))),
              const SizedBox(width: 8),
              Basma(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size(96, 44), foregroundColor: Renk.kiremit),
                  onPressed: () => _teklifYanit(m, false),
                  child: const Text('Reddet'),
                ),
              ),
            ]),
          ],
          const SizedBox(height: 4),
          Text(saat(m.zaman), style: const TextStyle(fontSize: 11, color: Renk.soluk)),
        ]),
      ),
    );
  }

  void _menu() {
    final k = _k!;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      sheetAnimationStyle: Hareket.altSayfa(context),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('İlanı görüntüle', style: TextStyle(fontWeight: FontWeight.w800)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailScreen(ilanId: k.ilanId)));
              },
            ),
            // Değerlendirme yalnızca gerçek bir görüşmeden sonra: satıcı en az bir kez yanıt vermiş olmalı.
            if (k.alici)
              ListTile(
                enabled: _saticiYazdi,
                title: const Text('Satıcıyı değerlendir', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: _saticiYazdi ? null : const Text('Satıcı sana yanıt verdikten sonra değerlendirebilirsin.'),
                onTap: () {
                  Navigator.pop(ctx);
                  _degerlendir();
                },
              ),
            ListTile(
              title: const Text('Kullanıcıyı engelle', style: TextStyle(fontWeight: FontWeight.w800)),
              onTap: () async {
                Navigator.pop(ctx);
                final ok = await onayIste(context, 'Engellemek istiyor musun?', '${k.karsiAd} sana mesaj gönderemez ve ilanlarını görmezsin.', 'Engelle', tehlike: true);
                if (!ok) return;
                try {
                  await engelle(k.karsiId);
                  if (!mounted) return;
                  Navigator.of(context).pop();
                  bildir(context, 'Kullanıcı engellendi');
                } catch (e) {
                  if (mounted) bildir(context, 'Engellenemedi: $e');
                }
              },
            ),
            ListTile(
              title: const Text('Şikayet et / bildir', style: TextStyle(fontWeight: FontWeight.w800, color: uyariRenk)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReportScreen(ilanId: k.ilanId, kullaniciId: k.karsiId)));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _degerlendir() async {
    final k = _k!;
    var puan = 0; // Hazır seçili yıldız yok: kullanıcı kendisi seçmeli.
    final yorum = TextEditingController();
    final gonder = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Satıcıyı değerlendir'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      tooltip: '$i yıldız',
                      onPressed: () => set(() => puan = i),
                      icon: Icon(i <= puan ? Icons.star : Icons.star_border, color: yildizRenk, size: 32),
                    ),
                ],
              ),
              TextField(controller: yorum, maxLines: 3, maxLength: 1000, decoration: const InputDecoration(hintText: 'Yorumun (isteğe bağlı)')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
            FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(100, 44)), onPressed: puan == 0 ? null : () => Navigator.pop(ctx, true), child: const Text('Gönder')),
          ],
        ),
      ),
    );
    if (gonder != true) return;
    try {
      await yorumYaz(k.id, k.karsiId, puan, yorum.text);
      if (mounted) bildir(context, 'Değerlendirmen için teşekkürler');
    } catch (e) {
      final m = '$e';
      if (mounted) {
        bildir(context, m.contains('duplicate') || m.contains('unique') ? 'Bu görüşme için zaten değerlendirme yaptın.' : 'Değerlendirme gönderilemedi. Satıcıyla karşılıklı mesajlaşmış olmalısın.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = _k;
    if (k == null) {
      return Scaffold(appBar: AppBar(), body: _hata != null ? HataKutusu(_hata!, tekrar: _yukle) : yukleniyor());
    }
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SaticiScreen(saticiId: k.karsiId, ad: k.karsiAd))),
          child: Row(
          children: [
            CircleAvatar(radius: 20, backgroundColor: Renk.cizgi, child: Text(k.bas, style: const TextStyle(fontWeight: FontWeight.w800, color: Renk.yesil))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(k.karsiAd, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Renk.murekkep), overflow: TextOverflow.ellipsis),
                  const Text('✓ Doğrulanmış · profili gör', style: TextStyle(fontSize: 12, color: Renk.yesil, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
        ),
        ),
        actions: [IconButton(icon: const Icon(Icons.more_vert), tooltip: 'Menü', onPressed: _menu)],
      ),
      body: Column(
        children: [
          if (k.ilanCins != null)
            InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailScreen(ilanId: k.ilanId))),
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${k.ilanCins} · ${k.ilanAdet} baş', style: const TextStyle(fontWeight: FontWeight.w800)),
                          if (k.ilanFiyat != null) Text(tl(k.ilanFiyat!), style: const TextStyle(fontWeight: FontWeight.w800, color: Renk.murekkep)),
                        ],
                      ),
                    ),
                    const Text('İlanı gör', style: TextStyle(color: Renk.yesil, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          if (_guvenli)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              decoration: BoxDecoration(color: const Color(0xFFFFF3D6), borderRadius: BorderRadius.circular(10), border: Border.all(color: altin)),
              child: Row(
                children: [
                  const Text('⚠  '),
                  const Expanded(
                    child: Text('Güvenli alışveriş: Hayvanı görmeden kapora veya ön ödeme gönderme. Şüpheli ilanı bildir.', style: TextStyle(fontSize: 13, height: 1.4)),
                  ),
                  IconButton(onPressed: () => setState(() => _guvenli = false), icon: const Icon(Icons.close, size: 18)),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _akis,
              builder: (context, s) {
                if (s.hasError) return HataKutusu('Mesajlar yüklenemedi: ${s.error}\n(Gerçek zamanlı akış için 002_ek_ozellikler.sql çalışmış olmalı.)');
                if (!s.hasData) return yukleniyor();
                final liste = s.data!.map(Mesaj.json).toList()..sort((a, b) => a.zaman.compareTo(b.zaman));
                _saticiYazdi = liste.any((m) => m.gonderen == k.karsiId);
                final okunmamis = liste.where((m) => m.gonderen != uid && m.okundu == null).length;
                if (okunmamis != _okunmamisGorulen) {
                  _okunmamisGorulen = okunmamis;
                  if (okunmamis > 0) {
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      try {
                        await okunduIsaretle(widget.konusmaId);
                        app.sayaclariYenile();
                      } catch (_) {}
                    });
                  }
                }
                // Sunucuya ulaşmış bekleyen mesajı ikinci kez gösterme.
                final sonBenim = liste.where((m) => m.gonderen == uid).toList();
                final bekleyen = _bekleyen.where((b) => !sonBenim.any((m) => m.metin == b.metin && !m.zaman.isBefore(b.zaman.subtract(const Duration(minutes: 2))))).toList();
                if (liste.isEmpty && bekleyen.isEmpty) {
                  return const Center(child: Text('Konuşmayı başlatmak için bir mesaj yaz.', style: TextStyle(color: Renk.soluk)));
                }
                // En yeni mesaj en altta: liste eskiden yeniye sıralı, ters çevrilmiş listede ilk öğe en yenidir.
                final ters = [...liste, ...bekleyen].reversed.toList();
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: ters.length,
                  itemBuilder: (_, n) {
                    final m = ters[n];
                    final benim = m.gonderen == uid;
                    if (m.teklif) return _teklifKarti(m, benim, k.ilanFiyat?.toDouble());
                    return Align(
                      alignment: benim ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.fromLTRB(12, 9, 12, 6),
                        decoration: BoxDecoration(
                          color: benim ? Renk.yesil : Renk.kart,
                          boxShadow: benim ? null : Golge.hafif,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(benim ? 16 : 4),
                            bottomRight: Radius.circular(benim ? 4 : 16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(m.metin, style: TextStyle(color: benim ? Colors.white : Renk.murekkep, fontSize: 15, height: 1.4)),
                            const SizedBox(height: 2),
                            Text('${saat(m.zaman)}${benim ? (m.id.startsWith('yerel-') ? ' …' : m.okundu != null ? ' ✓✓' : ' ✓') : ''}',
                                style: TextStyle(fontSize: 11, color: benim ? Colors.white70 : Renk.soluk)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Renk.cizgi))),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [for (final h in ['Son fiyat nedir?', 'Bakmaya gelebilirim', 'Nerede teslim?']) Cip(h, false, () => _gonder(h))],
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _mc,
                          onSubmitted: (_) => _gonder(),
                          // Klavyeden gönderince alan odakta kalsın: arka arkaya mesaj yazılabilsin.
                          onEditingComplete: () {},
                          textInputAction: TextInputAction.send,
                          decoration: InputDecoration(
                            hintText: 'Mesaj yaz',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Renk.cizgi)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: Renk.cizgi)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        style: IconButton.styleFrom(backgroundColor: Renk.yesil, minimumSize: const Size(48, 48)),
                        tooltip: 'Gönder',
                        onPressed: () => _gonder(),
                        icon: const Icon(Icons.send, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
