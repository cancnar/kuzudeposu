import 'package:flutter/material.dart';

import '../data.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'chat_screen.dart';
import 'talepler_screen.dart';
import 'detail_screen.dart';
import 'settings_screens.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<Map<String, dynamic>>> _f = bildirimler();

  String _simge(String? tur) => switch (tur) {
        'mesaj' => '✉',
        'yeni_ilan' => '+',
        'fiyat' => '₺',
        'yorum' => '★',
        'talep' => '🔎',
        _ => '•',
      };

  Future<void> _ac(Map<String, dynamic> n) async {
    if (n['read_at'] == null) {
      try {
        await bildirimOkundu(n['id'] as String);
      } catch (_) {}
    }
    app.sayaclariYenile();
    final d = (n['data'] as Map?) ?? {};
    if (!mounted) return;
    if (d['wanted_id'] != null) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TaleplerScreen()));
    } else if (d['conversation_id'] != null) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatScreen(konusmaId: d['conversation_id'] as String)));
    } else if (d['listing_id'] != null) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailScreen(ilanId: d['listing_id'] as String)));
    }
    if (mounted) setState(() { _f = bildirimler(); });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await hepsiniOkundu();
                app.sayaclariYenile();
                setState(() { _f = bildirimler(); });
              } catch (e) {
                if (mounted) bildir(context, 'İşlem yapılamadı: $e');
              }
            },
            child: const Text('Tümünü okundu say'),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _f,
        builder: (context, s) {
          if (s.connectionState != ConnectionState.done) return yukleniyor();
          if (s.hasError) return HataKutusu(s.error!, tekrar: () => setState(() { _f = bildirimler(); }));
          final liste = s.data!;
          return ListView(
            children: [
              if (liste.isEmpty) const Bos('Henüz bildirim yok', 'Mesaj, teklif, fiyat düşüşü ve kayıtlı aramana uyan yeni ilanlar burada görünür.'),
              for (final n in liste)
                InkWell(
                  onTap: () => _ac(n),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(color: n['read_at'] == null ? Colors.white : Colors.transparent, border: const Border(bottom: BorderSide(color: Renk.cizgi))),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 10, height: 10, margin: const EdgeInsets.only(top: 6, right: 10), decoration: BoxDecoration(color: n['read_at'] == null ? Renk.kiremit : Colors.transparent, shape: BoxShape.circle)),
                        CircleAvatar(backgroundColor: acikYesil, child: Text(_simge(n['type'] as String?), style: const TextStyle(color: Renk.yesil, fontWeight: FontWeight.w800, fontSize: 18))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(n['title'] as String, style: const TextStyle(fontWeight: FontWeight.w800))),
                                  Text(saat(DateTime.parse(n['created_at'] as String)), style: const TextStyle(color: Renk.soluk, fontSize: 12)),
                                ],
                              ),
                              if (n['body'] != null) Text(n['body'] as String, style: const TextStyle(color: Renk.soluk, height: 1.4)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotifSettingsScreen())),
                  child: const Text('Bildirim ayarları'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
