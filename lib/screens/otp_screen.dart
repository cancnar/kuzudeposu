import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import '../theme.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.telefon});
  final String telefon;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _kod = TextEditingController();
  bool _yukleniyor = false;
  int _deneme = 0;
  String? _hata;

  Future<void> _dogrula() async {
    final kod = _kod.text.trim();
    if (kod.length != 6) {
      setState(() => _hata = 'Lütfen 6 haneli kodu eksiksiz gir.');
      return;
    }
    if (_deneme >= 3) {
      setState(() => _hata = 'Çok fazla hatalı deneme. Geri dönüp yeni kod iste.');
      return;
    }
    setState(() {
      _hata = null;
      _yukleniyor = true;
    });
    try {
      await supabase.auth.verifyOTP(phone: widget.telefon, token: kod, type: OtpType.sms);
      // AuthGate oturumu görüp doğru ekrana geçer; bu ekranı kapat.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on AuthException {
      _deneme++;
      setState(() => _hata = 'Kod hatalı veya süresi dolmuş. Kalan deneme: ${3 - _deneme}');
    } catch (e) {
      setState(() => _hata = 'Bir sorun oluştu: $e');
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Doğrulama kodu', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text('${widget.telefon} numarasına gönderilen 6 haneli kodu gir.',
                      textAlign: TextAlign.center, style: const TextStyle(color: Renk.soluk)),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _kod,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 26, letterSpacing: 8, fontWeight: FontWeight.w800),
                    decoration: const InputDecoration(counterText: ''),
                  ),
                  if (_hata != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_hata!, style: const TextStyle(color: Renk.kiremit, fontWeight: FontWeight.w700)),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _yukleniyor ? null : _dogrula,
                    child: _yukleniyor
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Doğrula'),
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
