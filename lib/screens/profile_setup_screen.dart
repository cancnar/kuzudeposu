import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data.dart';
import '../konum.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets.dart';

/// Hem ilk kayıtta (profil yok) hem de profil düzenlemede kullanılır.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, this.duzenle = false});
  final bool duzenle;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  late final TextEditingController _ad;
  String? _il;
  String? _ilce;
  String? _adHata, _konumHata;
  late String _rol;
  bool _yukleniyor = false;
  String? _hata;

  static const _roller = {'yetistirici': 'Yetiştirici', 'tuccar': 'Tüccar', 'alici': 'Alıcı'};

  @override
  void initState() {
    super.initState();
    final p = widget.duzenle ? app.profil : null;
    _ad = TextEditingController(text: p?['full_name'] as String? ?? '');
    // Eski serbest metin kayıtları ("manisa") resmi yazılışa çevrilir
    final eskiIl = p?['il'] as String?;
    _il = ilBul(eskiIl)?.ad ?? (eskiIl == null || eskiIl.isEmpty ? null : eskiIl);
    _ilce = ilceBul(_il, p?['ilce'] as String?)?.ad ?? p?['ilce'] as String?;
    _rol = p?['role'] as String? ?? 'yetistirici';
  }

  Future<void> _kaydet() async {
    final ad = _ad.text.trim();
    final il = _il ?? '';
    final ilce = _ilce ?? '';
    setState(() {
      _adHata = ad.length < 3 ? 'Adını ve soyadını yaz.' : null;
      _konumHata = il.isEmpty || ilce.isEmpty ? 'İlini ve ilçeni seç.' : null;
    });
    if (_adHata != null || _konumHata != null) return;
    setState(() {
      _hata = null;
      _yukleniyor = true;
    });
    try {
      final alanlar = {'full_name': ad, 'il': il, 'ilce': ilce, 'role': _rol};
      if (widget.duzenle) {
        await db.from('profiles').update(alanlar).eq('id', uid!);
      } else {
        await db.from('profiles').insert({'id': uid, ...alanlar});
      }
      await app.profilYukle();
      if (!mounted) return;
      if (widget.duzenle) {
        Navigator.of(context).pop();
        bildir(context, 'Profil güncellendi');
      } else {
        bildir(context, 'Hoş geldin ${ad.split(' ').first}');
      }
    } on PostgrestException catch (e) {
      // 23503: oturumdaki hesap sunucuda yok (başka cihazda silinmiş). Teknik hata yerine yeniden giriş iste.
      if (e.code == '23503' && !widget.duzenle) {
        await app.oturumuKapat('Oturumun sona erdi. Devam etmek için tekrar giriş yap.');
        return;
      }
      setState(() => _hata = 'Kaydedilemedi. Bağlantını kontrol edip tekrar dene.');
    } catch (e) {
      setState(() => _hata = 'Bir sorun oluştu. Bağlantını kontrol edip tekrar dene.');
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.duzenle ? AppBar() : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.duzenle ? 'Profil bilgilerim' : 'Seni tanıyalım', style: baslik(30)),
                  const SizedBox(height: 8),
                  const Text('Alıcılar ilanında adını ve ilçeni görür. Telefon numaran gizli kalır.',
                      style: TextStyle(color: Renk.soluk, fontSize: 15, height: 1.5)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _ad,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.name],
                    onChanged: (_) => _adHata == null ? null : setState(() => _adHata = null),
                    decoration: InputDecoration(labelText: 'Ad soyad', errorText: _adHata),
                  ),
                  const SizedBox(height: 14),
                  KonumAlani(
                    il: _il,
                    ilce: _ilce,
                    hata: _konumHata,
                    secildi: (il, ilce) => setState(() {
                      _il = il;
                      _ilce = ilce;
                      _konumHata = null;
                    }),
                  ),
                  const SizedBox(height: 16),
                  const Text('Ben bir', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Wrap(
                    children: [for (final e in _roller.entries) Cip(e.value, _rol == e.key, () => setState(() => _rol = e.key))],
                  ),
                  if (_hata != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_hata!, style: const TextStyle(color: uyariRenk, fontWeight: FontWeight.w700)),
                    ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _yukleniyor ? null : _kaydet,
                    child: _yukleniyor
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(widget.duzenle ? 'Kaydet' : 'Başla'),
                  ),
                  if (!widget.duzenle)
                    TextButton(
                      onPressed: () => db.auth.signOut(),
                      child: const Text('Çıkış yap'),
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
