import 'package:flutter/material.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'phone_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Widget _madde(IconData ikon, String baslikYazi, String aciklama) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: Renk.okZemin, borderRadius: BorderRadius.circular(13)),
              child: Icon(ikon, color: Renk.okYazi, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(baslikYazi, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(aciklama, style: const TextStyle(fontSize: 14, color: Renk.soluk, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, kisit) => SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 480, minHeight: kisit.maxHeight),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Logo(boyut: 44),
                            const SizedBox(width: 10),
                            Text('Kuzu Deposu', style: baslik(24)),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Text('Hayvanını güvenle al, güvenle sat.', style: baslik(36).copyWith(height: 1.1, letterSpacing: -0.5)),
                        const SizedBox(height: 12),
                        const Text(
                          'Kuzudan tosuna, atından keçisine; yetiştiricilerle doğrudan buluş.',
                          style: TextStyle(fontSize: 17, height: 1.5, color: Renk.soluk),
                        ),
                        const SizedBox(height: 28),
                        _madde(Icons.verified_outlined, 'Telefonu doğrulanmış satıcılar', 'Her satıcı SMS koduyla doğrulanır.'),
                        _madde(Icons.sell_outlined, 'Küpe ve belge bilgisi', 'Küpe, sağlık raporu ve pasaport ilanda görünür.'),
                        _madde(Icons.shield_outlined, 'Şüpheli ilan gizlenir', 'Üç farklı kullanıcı bildirirse ilan yayından kalkar.'),
                        const Spacer(),
                        const SizedBox(height: 12),
                        Basma(
                          child: FilledButton(
                            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PhoneScreen())),
                            child: const Text('Telefon numaram ile devam et'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Basma(
                          child: OutlinedButton(
                            onPressed: () {
                              app.misafir = true;
                              app.yenile();
                            },
                            child: const Text('Giriş yapmadan ilanlara göz at'),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Devam ederek Kullanım Koşulları ve Gizlilik Politikası\'nı kabul etmiş olursun.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Renk.soluk, fontSize: 12, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
