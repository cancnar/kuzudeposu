import 'package:flutter/material.dart';

import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'phone_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Widget _madde(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(color: altin, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: const Text('✓', style: TextStyle(color: Renk.yesil, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(t, style: const TextStyle(fontSize: 16))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, kisit) => SingleChildScrollView(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 480, minHeight: kisit.maxHeight),
            child: IntrinsicHeight(
            child: Column(
              children: [
                Container(
                  height: (kisit.maxHeight * 0.42).clamp(280.0, 420.0),
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Renk.yesil,
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(36), bottomRight: Radius.circular(36)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Logo(boyut: 104, ters: true),
                      const SizedBox(height: 10),
                      Text('Kuzu Deposu', style: baslik(34, renk: Renk.krem)),
                      const SizedBox(height: 6),
                      const Text('Hayvanını güvenle al, güvenle sat', style: TextStyle(color: altin, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _madde('Telefonu doğrulanmış satıcılar'),
                      _madde('Satıcı puanı ve yorumları'),
                      _madde('Sürü ve tek hayvan ilanları'),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PhoneScreen())),
                        child: const Text('Telefon numaram ile devam et'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: () {
                          app.misafir = true;
                          app.yenile();
                        },
                        child: const Text('Giriş yapmadan ilanlara göz at'),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Devam ederek Kullanım Koşulları ve Gizlilik Politikası\'nı kabul etmiş olursun.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Renk.soluk, fontSize: 12),
                      ),
                    ],
                  ),
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
        ),
      ),
    );
  }
}
