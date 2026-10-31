import 'package:flutter/material.dart';

import '../data.dart';
import '../theme.dart';
import '../widgets.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key, this.ilanId, this.kullaniciId});
  final String? ilanId;
  final String? kullaniciId;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  String? _sebep;
  final _detay = TextEditingController();
  bool _yukleniyor = false;
  String? _hata;

  Future<void> _gonder() async {
    if (_sebep == null) {
      setState(() => _hata = 'Bir sebep seç.');
      return;
    }
    setState(() {
      _hata = null;
      _yukleniyor = true;
    });
    try {
      await sikayetEt(ilanId: widget.ilanId, kullaniciId: widget.kullaniciId, sebep: sikayetSebepleri[_sebep]!, detay: _detay.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      bildir(context, 'Şikayetin alındı, incelenecek');
    } catch (e) {
      setState(() => _hata = 'Gönderilemedi: $e');
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Şikayet et')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          const Text('Sorun nedir?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 10),
          for (final s in sikayetSebepleri.keys)
            GestureDetector(
              onTap: () => setState(() => _sebep = s),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _sebep == s ? Renk.yesil : Renk.cizgi, width: _sebep == s ? 2 : 1),
                ),
                child: Row(
                  children: [
                    Icon(_sebep == s ? Icons.radio_button_checked : Icons.radio_button_off, color: Renk.yesil),
                    const SizedBox(width: 12),
                    Expanded(child: Text(s)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
          TextField(controller: _detay, maxLines: 3, maxLength: 1000, decoration: const InputDecoration(labelText: 'Eklemek istediğin bir şey var mı? (isteğe bağlı)', alignLabelWithHint: true)),
          if (_hata != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_hata!, style: const TextStyle(color: uyariRenk, fontWeight: FontWeight.w700))),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Renk.kiremit),
            onPressed: _yukleniyor ? null : _gonder,
            child: const Text('Şikayeti gönder'),
          ),
        ],
      ),
    );
  }
}
