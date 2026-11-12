import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'metinler_screen.dart';
import 'otp_screen.dart';

/// Giriş gerektiren bir işlemden önce çağrılır. Oturum yoksa giriş ekranını açar.
/// Giriş yoksa telefon ekranını açar ve false döner. [ilanId] verilirse girişten sonra o ilana geri dönülür.
Future<bool> girisGerekli(BuildContext context, {String? ilanId}) async {
  if (db.auth.currentSession != null) return true;
  if (ilanId != null) app.bekleyenIlanId = ilanId;
  bildir(context, 'Devam etmek için telefon numaranla giriş yap.');
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PhoneScreen()));
  return false;
}

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
    if (kilitBitis != null && DateTime.now().isBefore(kilitBitis!)) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LockScreen()));
      return;
    }
    setState(() {
      _hata = null;
      _yukleniyor = true;
    });
    try {
      await db.auth.signInWithOtp(phone: numara);
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
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(alignment: Alignment.centerLeft, child: Logo(boyut: 46)),
                  const SizedBox(height: 16),
                  Text('Telefon numaranı gir', style: baslik(30)),
                  const SizedBox(height: 8),
                  const Text('Sana SMS ile 6 haneli bir doğrulama kodu göndereceğiz. Şifre gerekmez.',
                      style: TextStyle(color: Renk.soluk, fontSize: 15, height: 1.5)),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _tel,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumberNational],
                    inputFormatters: [TelefonBicimi()],
                    style: const TextStyle(fontSize: 20),
                    decoration: const InputDecoration(labelText: 'Cep telefonu', prefixText: '+90  ', hintText: '532 123 45 67'),
                  ),
                  const SizedBox(height: 16),
                  CheckboxListTile(
                    value: _kvkk,
                    onChanged: (v) => setState(() => _kvkk = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: const SartlarMetni(once: '', sonra: '\'ni okudum, kabul ediyorum.', stil: TextStyle(fontSize: 14, height: 1.4, color: Renk.murekkep)),
                  ),
                  if (_hata != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Text(_hata!, style: const TextStyle(color: uyariRenk, fontWeight: FontWeight.w700)),
                    ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _yukleniyor ? null : _kodGonder,
                    child: _yukleniyor
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Kodu gönder'),
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

/// Yazarken "555 999 99 99" biçiminde gruplar; baştaki 0 ve +90 atılır, en fazla 10 hane.
class TelefonBicimi extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue eski, TextEditingValue yeni) {
    var d = yeni.text.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('90') && d.length > 10) d = d.substring(2);
    if (d.startsWith('0')) d = d.substring(1);
    if (d.length > 10) d = d.substring(0, 10);
    final b = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i == 3 || i == 6 || i == 8) b.write(' ');
      b.write(d[i]);
    }
    final t = b.toString();
    return TextEditingValue(text: t, selection: TextSelection.collapsed(offset: t.length));
  }
}
