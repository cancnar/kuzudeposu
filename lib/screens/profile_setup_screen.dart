import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import '../theme.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, required this.onSaved});
  final VoidCallback onSaved;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _ad = TextEditingController();
  final _il = TextEditingController();
  final _ilce = TextEditingController();
  String _rol = 'yetistirici';
  bool _yukleniyor = false;
  String? _hata;

  static const _roller = {
    'yetistirici': 'Yetiştirici',
    'tuccar': 'Tüccar',
    'alici': 'Alıcı',
  };

  Future<void> _kaydet() async {
    final ad = _ad.text.trim();
    final il = _il.text.trim();
    final ilce = _ilce.text.trim();
    if (ad.length < 3) {
      setState(() => _hata = 'Ad soyad en az 3 karakter olmalı.');
      return;
    }
    if (il.isEmpty || ilce.isEmpty) {
      setState(() => _hata = 'İl ve ilçe alanlarını doldur.');
      return;
    }
    setState(() {
      _hata = null;
      _yukleniyor = true;
    });
    try {
      await supabase.from('profiles').insert({
        'id': supabase.auth.currentUser!.id,
        'full_name': ad,
        'il': il,
        'ilce': ilce,
        'role': _rol,
      });
      widget.onSaved();
    } on PostgrestException catch (e) {
      setState(() => _hata = 'Kaydedilemedi: ${e.message}');
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
                  Text('Seni tanıyalım', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  TextField(controller: _ad, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Ad soyad')),
                  const SizedBox(height: 12),
                  TextField(controller: _il, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'İl')),
                  const SizedBox(height: 12),
                  TextField(controller: _ilce, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'İlçe')),
                  const SizedBox(height: 16),
                  const Text('Ben bir...', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final e in _roller.entries)
                        ChoiceChip(
                          label: Text(e.value),
                          selected: _rol == e.key,
                          onSelected: (_) => setState(() => _rol = e.key),
                        ),
                    ],
                  ),
                  if (_hata != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_hata!, style: const TextStyle(color: Renk.kiremit, fontWeight: FontWeight.w700)),
                    ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _yukleniyor ? null : _kaydet,
                    child: _yukleniyor
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Kaydet ve devam et'),
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
