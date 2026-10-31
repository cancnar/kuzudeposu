import 'package:flutter/material.dart';

import '../data.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'detail_screen.dart';
import 'report_screen.dart';

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
      _akis = db.from('messages').stream(primaryKey: ['id']).eq('conversation_id', widget.konusmaId).order('created_at');
      if (mounted) setState(() => _k = k);
      await okunduIsaretle(widget.konusmaId);
      app.sayaclariYenile();
    } catch (e) {
      if (mounted) setState(() => _hata = e);
    }
  }

  Future<void> _gonder([String? hazir]) async {
    final m = (hazir ?? _mc.text).trim();
    if (m.isEmpty) return;
    if (hazir == null) _mc.clear();
    try {
      await mesajGonder(widget.konusmaId, m);
    } catch (e) {
      if (hazir == null) _mc.text = m;
      if (mounted) bildir(context, 'Mesaj gönderilemedi. Kullanıcı seni veya sen onu engellemiş olabilirsin.');
    }
  }

  void _menu() {
    final k = _k!;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
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
            if (k.alici)
              ListTile(
                title: const Text('Satıcıyı değerlendir', style: TextStyle(fontWeight: FontWeight.w800)),
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
    var puan = 5;
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
            FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(100, 44)), onPressed: () => Navigator.pop(ctx, true), child: const Text('Gönder')),
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
        bildir(context, m.contains('duplicate') || m.contains('unique') ? 'Bu görüşme için zaten değerlendirme yaptın.' : 'Değerlendirme gönderilemedi. Önce satıcıya mesaj yazmış olmalısın.');
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
        title: Row(
          children: [
            CircleAvatar(radius: 20, backgroundColor: Renk.cizgi, child: Text(k.bas, style: const TextStyle(fontWeight: FontWeight.w800, color: Renk.yesil))),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(k.karsiAd, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Renk.murekkep), overflow: TextOverflow.ellipsis),
                  const Text('✓ Doğrulanmış', style: TextStyle(fontSize: 12, color: Renk.yesil, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ],
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
                          if (k.ilanFiyat != null) Text(tl(k.ilanFiyat!), style: const TextStyle(fontWeight: FontWeight.w800, color: Renk.kiremit)),
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
                final liste = s.data!.map(Mesaj.json).toList();
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
                if (liste.isEmpty) {
                  return const Center(child: Text('Konuşmayı başlatmak için bir mesaj yaz.', style: TextStyle(color: Renk.soluk)));
                }
                final ters = liste.reversed.toList();
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: ters.length,
                  itemBuilder: (_, n) {
                    final m = ters[n];
                    final benim = m.gonderen == uid;
                    return Align(
                      alignment: benim ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .78),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.fromLTRB(12, 9, 12, 6),
                        decoration: BoxDecoration(
                          color: benim ? Renk.yesil : Colors.white,
                          border: benim ? null : Border.all(color: Renk.cizgi),
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
                            Text('${saat(m.zaman)}${benim ? (m.okundu != null ? ' ✓✓' : ' ✓') : ''}',
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
