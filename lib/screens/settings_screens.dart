import 'package:flutter/material.dart';

import '../data.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'metinler_screen.dart';
import 'profile_setup_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Ayarlar')),
        body: ListView(
          children: [
            Bolum('Hesap', [
              Satir('Profil bilgilerim', deger: app.profil?['full_name'] as String?, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileSetupScreen(duzenle: true)))),
              Satir('Telefon numaram', deger: maske(db.auth.currentUser?.phone), onTap: () => bildir(context, 'Numara değişikliği için destek ile iletişime geç')),
            ]),
            Bolum('Tercihler', [
              Satir('Bildirimler', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotifSettingsScreen()))),
              Satir('Kayıtlı aramalarım', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SavedSearchesScreen()))),
              Satir('Gizlilik', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PrivacyScreen()))),
            ]),
            Bolum('Görünüm', [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Yazı boyutu', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 8),
                    Wrap(runSpacing: 8, children: [for (final y in ['Normal', 'Büyük', 'Çok büyük']) Cip(y, app.yazi == y, () => app.yaziDegistir(y))]),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Renk.krem, borderRadius: BorderRadius.circular(10)),
                      child: const Text('Örnek: Simental düve · 12 baş · 1.740.000 ₺'),
                    ),
                  ],
                ),
              ),
              AnahtarSatir(
                'Hareketi azalt',
                app.tercih['azalt'] ?? false,
                (_) => app.tercihDegistir('azalt'),
                alt: 'Kayan geçişler yerine solma; telefonun Hareketi Azalt ayarı da geçerli',
              ),
            ]),
            Bolum('Destek', [
              Satir('Kullanım koşulları', onTap: () => kosullariAc(context)),
              Satir('KVKK aydınlatma metni', onTap: () => kvkkAc(context)),
              Satir('Yardım ve destek', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const YardimScreen()))),
              Satir('Hakkında', deger: 'Sürüm 0.2.0', onTap: () => bildir(context, 'Kuzu Deposu · test sürümü')),
            ]),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class NotifSettingsScreen extends StatelessWidget {
  const NotifSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: app,
      builder: (context, _) {
        Widget a(String k, String t, [String? alt]) => AnahtarSatir(t, app.tercih[k] ?? false, (_) => app.tercihDegistir(k), alt: alt);
        return Scaffold(
          appBar: AppBar(title: const Text('Bildirimler')),
          body: ListView(
            children: [
              Bolum('Mesajlar', [a('msg', 'Yeni mesaj', 'Biri sana yazdığında haber ver')]),
              Bolum('İlanlar', [
                a('newl', 'Aramama uyan yeni ilan', 'Kayıtlı aramalarına göre'),
                a('price', 'Favori ilan fiyatı değişti'),
                a('expire', 'İlanım sona eriyor', 'Süre dolmadan 3 gün önce'),
              ]),
              Bolum('Duyurular', [a('promo', 'Kampanya ve haberler', 'Öne çıkarma indirimleri, yenilikler')]),
              Bolum('Sessiz saatler', [a('quiet', 'Gece bildirim gönderme', '22:00 – 07:00 arası')]),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Not: Bu tercihler şimdilik bu cihazda saklanır. Telefona anlık bildirim (push) sonraki aşamada eklenecek.', style: TextStyle(color: Renk.soluk, fontSize: 13, height: 1.5)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  Future<void> _telefon(bool v) async {
    try {
      await db.from('profiles').update({'show_phone': v}).eq('id', uid!);
      app.profil = {...?app.profil, 'show_phone': v};
      app.yenile();
      setState(() {});
    } catch (e) {
      if (mounted) bildir(context, 'Güncellenemedi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gizlilik')),
      body: ListView(
        children: [
          Bolum('Başkaları ne görür?', [
            AnahtarSatir('Telefon numaram ilanlarda görünsün', (app.profil?['show_phone'] as bool?) ?? false, _telefon, alt: 'Kapalıyken alıcılar sana uygulama içinden yazar.'),
          ]),
          Bolum('Güvenlik ve haklar', [
            Satir('Engellediğim kişiler', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BlockedScreen()))),
            Satir('KVKK aydınlatma metni', onTap: () => bildir(context, 'Metin yayın öncesi hukuki incelemeden sonra eklenecek')),
          ]),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Tam adresin hiçbir zaman gösterilmez. Sadece il ve ilçe görünür.', style: TextStyle(color: Renk.soluk, height: 1.5)),
          ),
        ],
      ),
    );
  }
}

class BlockedScreen extends StatefulWidget {
  const BlockedScreen({super.key});

  @override
  State<BlockedScreen> createState() => _BlockedScreenState();
}

class _BlockedScreenState extends State<BlockedScreen> {
  late Future<List<Map<String, dynamic>>> _f = engellenenler();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Engellediğim kişiler')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _f,
        builder: (context, s) {
          if (s.connectionState != ConnectionState.done) return yukleniyor();
          if (s.hasError) return HataKutusu(s.error!);
          final l = s.data!;
          if (l.isEmpty) return const Center(child: Text('Kimseyi engellemedin.', style: TextStyle(color: Renk.soluk)));
          return ListView(
            children: [
              for (final b in l)
                ListTile(
                  title: Text(((b['kisi'] as Map?)?['full_name'] as String?) ?? 'Kullanıcı', style: const TextStyle(fontWeight: FontWeight.w800)),
                  trailing: TextButton(
                    onPressed: () async {
                      await engelKaldir(b['blocked_id'] as String);
                      setState(() { _f = engellenenler(); });
                    },
                    child: const Text('Engeli kaldır'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class SavedSearchesScreen extends StatefulWidget {
  const SavedSearchesScreen({super.key});

  @override
  State<SavedSearchesScreen> createState() => _SavedSearchesScreenState();
}

class _SavedSearchesScreenState extends State<SavedSearchesScreen> {
  late Future<List<Map<String, dynamic>>> _f = kayitliAramalar();

  void _yenile() => setState(() { _f = kayitliAramalar(); });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kayıtlı aramalarım')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _f,
        builder: (context, s) {
          if (s.connectionState != ConnectionState.done) return yukleniyor();
          if (s.hasError) return HataKutusu(s.error!, tekrar: _yenile);
          final l = s.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text('Bildirim açıkken aramana uyan yeni ilan çıkınca haber veririz.', style: TextStyle(color: Renk.soluk, height: 1.5)),
              const SizedBox(height: 12),
              if (l.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Text('Kayıtlı aramayı filtre ekranından ekleyebilirsin.', textAlign: TextAlign.center, style: TextStyle(color: Renk.soluk))),
              for (final a in l)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: kutu(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a['title'] as String, style: baslik(18)),
                                Text(Filtre.json(a['filters']).aktif().map((e) => e.metin).join(' · '), style: const TextStyle(color: Renk.soluk, fontSize: 13)),
                              ],
                            ),
                          ),
                          Switch(
                            value: (a['notify'] as bool?) ?? true,
                            activeColor: Colors.white,
                            activeTrackColor: Renk.yesil,
                            onChanged: (v) async {
                              await aramaBildirim(a['id'] as String, v);
                              _yenile();
                            },
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              app.filtre = Filtre.json(a['filters']);
                              app.arama = '';
                              app.sekme = 0;
                              app.yenile();
                              Navigator.of(context).popUntil((r) => r.isFirst);
                            },
                            child: const Text('Sonuçları gör'),
                          ),
                          TextButton(
                            onPressed: () async {
                              await aramaSil(a['id'] as String);
                              _yenile();
                            },
                            child: const Text('Sil', style: TextStyle(color: uyariRenk)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
