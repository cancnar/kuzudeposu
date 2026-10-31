import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

DateTime? kilitBitis;

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.telefon});
  final String telefon;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _kod = TextEditingController();
  bool _yukleniyor = false;
  int _kalan = 3;
  String? _hata;

  Future<void> _dogrula() async {
    final kod = _kod.text.trim();
    if (kod.length != 6) {
      setState(() => _hata = '6 haneli kodu eksiksiz gir.');
      return;
    }
    setState(() {
      _hata = null;
      _yukleniyor = true;
    });
    try {
      await db.auth.verifyOTP(phone: widget.telefon, token: kod, type: OtpType.sms);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on AuthException {
      _kalan--;
      if (_kalan <= 0) {
        kilitBitis = DateTime.now().add(const Duration(minutes: 15));
        if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LockScreen()));
        return;
      }
      setState(() => _hata = 'Kod hatalı veya süresi dolmuş. $_kalan deneme hakkın kaldı.');
    } catch (e) {
      setState(() => _hata = 'Bir sorun oluştu: $e');
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  Future<void> _tekrar() async {
    try {
      await db.auth.signInWithOtp(phone: widget.telefon);
      if (mounted) bildir(context, 'Yeni kod gönderildi');
    } on AuthException catch (e) {
      if (mounted) bildir(context, 'Kod gönderilemedi: ${e.message}');
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
                  Text('Doğrulama kodunu gir', style: baslik(30)),
                  const SizedBox(height: 8),
                  Text('${maskeMetin(widget.telefon)} numarasına 6 haneli kod gönderdik.',
                      style: const TextStyle(color: Renk.soluk, fontSize: 15, height: 1.5)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _kod,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 30, letterSpacing: 10, fontWeight: FontWeight.w800),
                    decoration: InputDecoration(
                      counterText: '',
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _hata != null ? uyariRenk : Renk.cizgi),
                      ),
                    ),
                  ),
                  if (_hata != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('⚠ $_hata', style: const TextStyle(color: uyariRenk, fontWeight: FontWeight.w700)),
                    ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _yukleniyor ? null : _dogrula,
                    child: _yukleniyor
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Doğrula'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(onPressed: _tekrar, child: const Text('Kodu tekrar gönder')),
                      TextButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NoCodeScreen(telefon: widget.telefon, tekrar: _tekrar))),
                        child: const Text('Kod gelmedi mi?'),
                      ),
                    ],
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

String maskeMetin(String tel) {
  final t = tel.replaceAll(RegExp(r'\D'), '');
  if (t.length < 12) return tel;
  return '+90 ${t.substring(2, 5)} *** ** ${t.substring(10)}';
}

class NoCodeScreen extends StatelessWidget {
  const NoCodeScreen({super.key, required this.telefon, required this.tekrar});
  final String telefon;
  final Future<void> Function() tekrar;

  Widget _madde(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('•  ', style: TextStyle(color: Renk.yesil, fontWeight: FontWeight.w800)),
            Expanded(child: Text(t, style: const TextStyle(fontSize: 15, height: 1.4))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Kod gelmedi mi?', style: baslik(30)),
              const SizedBox(height: 8),
              Text('${maskeMetin(telefon)} numarasına gönderdiğimiz kod ulaşmadıysa:',
                  style: const TextStyle(color: Renk.soluk, fontSize: 15, height: 1.5)),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Renk.cizgi)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Şunları dene', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    _madde('Telefonunun sinyal ve internet bağlantısını kontrol et.'),
                    _madde('Numarayı doğru yazdığından emin ol.'),
                    _madde('SMS kutunda engellenen veya spam mesajlara bak.'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  await tekrar();
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('Kodu tekrar gönder'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: const Text('Numarayı değiştir'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kalan = (kilitBitis ?? DateTime.now()).difference(DateTime.now());
    final bitti = kalan.isNegative || kalan.inSeconds == 0;
    final dk = (kalan.inSeconds.clamp(0, 99999) ~/ 60).toString().padLeft(2, '0');
    final sn = (kalan.inSeconds.clamp(0, 99999) % 60).toString().padLeft(2, '0');
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.lock_outline, size: 64, color: Renk.yesil),
              const SizedBox(height: 16),
              Text('Çok fazla deneme yaptın', style: baslik(28), textAlign: TextAlign.center),
              const SizedBox(height: 10),
              const Text('Hesabını korumak için kısa bir süre beklemen gerekiyor.',
                  style: TextStyle(color: Renk.soluk, fontSize: 15, height: 1.5), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Renk.cizgi)),
                child: Column(
                  children: [
                    const Text('Kalan süre', style: TextStyle(color: Renk.soluk)),
                    Text(bitti ? '00:00' : '$dk:$sn', style: baslik(44)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: bitti ? () => Navigator.of(context).popUntil((r) => r.isFirst) : null,
                child: Text(bitti ? 'Tekrar dene' : 'Daha sonra tekrar dene'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: () {
                  app.misafir = true;
                  app.yenile();
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
                child: const Text('Giriş yapmadan ilanlara göz at'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
