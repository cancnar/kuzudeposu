import 'package:flutter/material.dart';

import '../data.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'chat_screen.dart';
import 'shell.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  Future<List<Konusma>>? _f;
  bool _sadeceOkunmamis = false;

  @override
  void initState() {
    super.initState();
    if (db.auth.currentSession != null) _f = konusmalar();
  }

  void _yenile() {
    setState(() => _f = konusmalar());
    app.sayaclariYenile();
  }

  @override
  Widget build(BuildContext context) {
    if (_f == null) return const GirisIste('Mesajların burada', 'Satıcılarla yazışmak için giriş yap.');
    return FutureBuilder<List<Konusma>>(
      future: _f,
      builder: (context, s) {
        if (s.connectionState != ConnectionState.done) return yukleniyor();
        if (s.hasError) return HataKutusu(s.error!, tekrar: _yenile);
        final tum = s.data!;
        if (tum.isEmpty) {
          return const Bos('Henüz mesajın yok', 'Bir ilandaki satıcıya yazdığında konuşmalar burada görünür.');
        }
        final liste = _sadeceOkunmamis ? tum.where((k) => k.okunmamis > 0).toList() : tum;
        return RefreshIndicator(
          onRefresh: () async => _yenile(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Text('Mesajlar', style: baslik(28))),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(children: [
                  Cip('Tümü', !_sadeceOkunmamis, () => setState(() => _sadeceOkunmamis = false)),
                  Cip('Okunmamış', _sadeceOkunmamis, () => setState(() => _sadeceOkunmamis = true)),
                ]),
              ),
              if (liste.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Text('Okunmamış mesajın yok.', textAlign: TextAlign.center, style: TextStyle(color: Renk.soluk))),
              for (final k in liste)
                InkWell(
                  onTap: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(konusmaId: k.id)));
                    if (mounted) _yenile();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: k.okunmamis > 0 ? Colors.white : Colors.transparent, border: const Border(bottom: BorderSide(color: Renk.cizgi))),
                    child: Row(
                      children: [
                        CircleAvatar(radius: 26, backgroundColor: Renk.cizgi, child: Text(k.bas, style: const TextStyle(fontWeight: FontWeight.w800, color: Renk.yesil))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(k.karsiAd, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  Text(k.son == null ? '' : saat(k.son!.zaman), style: const TextStyle(color: Renk.soluk, fontSize: 12)),
                                ],
                              ),
                              if (k.ilanCins != null)
                                Text('${k.ilanCins} · ${k.ilanAdet} baş', style: const TextStyle(color: Renk.yesil, fontWeight: FontWeight.w800, fontSize: 12)),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      k.son?.metin ?? 'Henüz mesaj yok',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: k.okunmamis > 0 ? Renk.murekkep : Renk.soluk, fontWeight: k.okunmamis > 0 ? FontWeight.w800 : FontWeight.w400),
                                    ),
                                  ),
                                  if (k.okunmamis > 0)
                                    Container(
                                      constraints: const BoxConstraints(minWidth: 22),
                                      height: 22,
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                      decoration: BoxDecoration(color: Renk.kiremit, borderRadius: BorderRadius.circular(11)),
                                      alignment: Alignment.center,
                                      child: Text('${k.okunmamis}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
