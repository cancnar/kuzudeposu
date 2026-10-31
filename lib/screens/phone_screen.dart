import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import '../theme.dart';
import 'otp_screen.dart';

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final _tel = TextEditingController();
  bool _kvkk = false;
  bool _yukleniyor = false;
  String? _hata;

  /// 5XX XXX XX XX biçimini +905XXXXXXXXX yapar; geçersizse null döner.
  String? _e164(String girdi) {
    var s = girdi.replaceAll(RegExp(r'\D'), '');
    if (s.startsWith('90') && s.length == 12) s = s.substring(2);
    if (s.startsWith('0')) s = s.substring(1);
    if (s.length != 10 || !s.startsWith('5')) return null;
    return '+90$s';
  }

  Future<void> _kodGonder() async {
    final numara = _e164(_tel.text);
    if (numara == null) {
      setState(() => _hata = 'Geçerli bir cep telefonu numarası gir (5XX XXX XX XX).');
      return;
    }
    if (!_kvkk) {
      setState(() => _hata = 'Devam etmek için kullanım koşullarını ve KVKK metnini kabul etmelisin.');
      return;
    }
    setState(() {
      _hata = null;
      _yukleniyor = true;
    });
    try {
      await supabase.auth.signInWithOtp(phone: numara);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => OtpScreen(telefon: numara)));
    } on AuthException catch (e) {
      setState(() => _hata = 'Kod gönderilemedi: ${e.message}');
    } catch (e) {
      setState(() => _hata = 'Bir sorun oluştu: $e');
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Kuzu Deposu', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  const Text('Telefon numaranla giriş yap. Şifre yok, sana bir doğrulama kodu göndereceğiz.',
                      textAlign: TextAlign.center, style: TextStyle(color: Renk.soluk)),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _tel,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Cep telefonu', prefixText: '+90  ', hintText: '532 123 45 67'),
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: _kvkk,
                    onChanged: (v) => setState(() => _kvkk = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Kullanım koşullarını ve KVKK aydınlatma metnini okudum, kabul ediyorum.',
                        style: TextStyle(fontSize: 13)),
                  ),
                  if (_hata != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Text(_hata!, style: const TextStyle(color: Renk.kiremit, fontWeight: FontWeight.w700)),
                    ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _yukleniyor ? null : _kodGonder,
                    child: _yukleniyor
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Kod gönder'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
