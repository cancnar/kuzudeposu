import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models.dart';
import 'theme.dart';

TextStyle baslik(double boyut, {Color? renk}) =>
    GoogleFonts.fraunces(fontSize: boyut, fontWeight: FontWeight.w700, color: renk ?? Renk.murekkep);

const altin = Color(0xFFE8C872);
const yildizRenk = Color(0xFF7A5200);
const acikYesil = Color(0xFFE8F0DC);
const uyariRenk = Color(0xFFA32D2D);

void bildir(BuildContext c, String m) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 3)));
}

class Logo extends StatelessWidget {
  const Logo({super.key, this.boyut = 34, this.ters = false});
  final double boyut;
  final bool ters;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(boyut), painter: _LogoCizici(ters));
}

class _LogoCizici extends CustomPainter {
  _LogoCizici(this.ters);
  final bool ters;
  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 64;
    final bg = ters ? Renk.krem : Renk.yesil;
    final fg = ters ? Renk.yesil : Renk.krem;
    final mu = ters ? altin : Renk.kiremit;
    final boynuz = ters ? Renk.yesil : altin;
    canvas.drawCircle(Offset(32 * k, 32 * k), 30 * k, Paint()..color = bg);
    final hp = Paint()
      ..color = boynuz
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * k
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(Path()..moveTo(22 * k, 27 * k)..cubicTo(14 * k, 27 * k, 12 * k, 19 * k, 14 * k, 14 * k), hp);
    canvas.drawPath(Path()..moveTo(42 * k, 27 * k)..cubicTo(50 * k, 27 * k, 52 * k, 19 * k, 50 * k, 14 * k), hp);
    canvas.drawOval(Rect.fromCenter(center: Offset(32 * k, 38 * k), width: 24 * k, height: 28 * k), Paint()..color = fg);
    canvas.drawCircle(Offset(26 * k, 33 * k), 2 * k, Paint()..color = bg);
    canvas.drawCircle(Offset(38 * k, 33 * k), 2 * k, Paint()..color = bg);
    canvas.drawOval(Rect.fromCenter(center: Offset(32 * k, 46 * k), width: 14 * k, height: 10 * k), Paint()..color = mu);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class Cip extends StatelessWidget {
  const Cip(this.yazi, this.secili, this.onTap, {super.key});
  final String yazi;
  final bool secili;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(yazi),
          selected: secili,
          onSelected: (_) => onTap(),
          selectedColor: Renk.yesil,
          backgroundColor: Colors.white,
          showCheckmark: false,
          labelStyle: TextStyle(color: secili ? Colors.white : Renk.murekkep, fontWeight: FontWeight.w700),
          side: const BorderSide(color: Renk.cizgi),
        ),
      );
}

class FotoKutusu extends StatelessWidget {
  const FotoKutusu({super.key, this.url, this.yukseklik = 120, this.yaricap = 0});
  final String? url;
  final double yukseklik;
  final double yaricap;
  @override
  Widget build(BuildContext context) {
    final bos = Container(
      height: yukseklik,
      width: double.infinity,
      color: Renk.cizgi,
      alignment: Alignment.center,
      child: Icon(Icons.pets, color: Renk.soluk.withOpacity(.5), size: yukseklik > 90 ? 36 : 22),
    );
    final u = url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(yaricap),
      child: u == null
          ? bos
          : Image.network(u, height: yukseklik, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => bos),
    );
  }
}

class IlanKarti extends StatelessWidget {
  const IlanKarti({super.key, required this.ilan, required this.onTap, required this.favori, required this.onFavori, this.durumGoster = false});
  final Ilan ilan;
  final VoidCallback onTap;
  final bool favori;
  final VoidCallback onFavori;
  final bool durumGoster;

  @override
  Widget build(BuildContext context) {
    final i = ilan;
    final alt = i.suru
        ? '${i.adet} baş · ${i.yasMetni} · ort. ${sayi(i.agirlik)} kg'
        : '${i.yasMetni} · ${sayi(i.agirlik)} kg';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Renk.cizgi)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    FotoKutusu(url: i.foto.isEmpty ? null : i.foto.first, yukseklik: 130),
                    if (i.suru)
                      Positioned(
                        left: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: altin, borderRadius: BorderRadius.circular(8)),
                          child: Text('Sürü · ${i.adet} baş', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Renk.murekkep)),
                        ),
                      ),
                    if (durumGoster && !i.aktif)
                      Positioned(
                        left: 10,
                        top: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: Renk.murekkep, borderRadius: BorderRadius.circular(8)),
                          child: Text(i.durum == 'satildi' ? 'Satıldı' : 'Yayında değil',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Colors.white)),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(child: Text('${i.cins} (${i.cinsiyetAd.toLowerCase()})', style: baslik(18), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                          Text(tl(i.toplam), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Renk.kiremit)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('$alt · ${sayi(i.kgFiyat)} ₺/kg', style: const TextStyle(color: Renk.soluk, fontSize: 13)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(child: Text(i.yer, style: const TextStyle(color: Renk.soluk, fontSize: 13), overflow: TextOverflow.ellipsis)),
                          Text(
                            i.saticiPuanSayisi > 0 ? '★ ${puanYaz(i.saticiPuan)} (${i.saticiPuanSayisi})' : 'Yeni satıcı',
                            style: const TextStyle(color: yildizRenk, fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: Material(
              color: Colors.white.withOpacity(.92),
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: favori ? 'Favorilerden çıkar' : 'Favorilere ekle',
                onPressed: onFavori,
                icon: Icon(favori ? Icons.favorite : Icons.favorite_border, color: Renk.kiremit),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class Bolum extends StatelessWidget {
  const Bolum(this.baslikYazi, this.cocuklar, {super.key});
  final String baslikYazi;
  final List<Widget> cocuklar;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
            child: Text(baslikYazi, style: const TextStyle(color: Renk.soluk, fontWeight: FontWeight.w800)),
          ),
          Container(
            decoration: const BoxDecoration(color: Colors.white, border: Border.symmetric(horizontal: BorderSide(color: Renk.cizgi))),
            child: Column(children: cocuklar),
          ),
        ],
      );
}

class Satir extends StatelessWidget {
  const Satir(this.yazi, {super.key, this.deger, this.onTap, this.renk});
  final String yazi;
  final String? deger;
  final VoidCallback? onTap;
  final Color? renk;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Renk.cizgi))),
          child: Row(
            children: [
              Expanded(child: Text(yazi, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: renk ?? Renk.murekkep))),
              if (deger != null) Flexible(child: Text(deger!, style: const TextStyle(color: Renk.soluk), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: Renk.soluk),
            ],
          ),
        ),
      );
}

class AnahtarSatir extends StatelessWidget {
  const AnahtarSatir(this.yazi, this.deger, this.degisti, {super.key, this.alt});
  final String yazi;
  final String? alt;
  final bool deger;
  final ValueChanged<bool> degisti;
  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Renk.cizgi))),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(yazi, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  if (alt != null && alt!.isNotEmpty) Text(alt!, style: const TextStyle(color: Renk.soluk, fontSize: 13)),
                ],
              ),
            ),
            Switch(value: deger, onChanged: degisti, activeColor: Colors.white, activeTrackColor: Renk.yesil),
          ],
        ),
      );
}

class Bos extends StatelessWidget {
  const Bos(this.baslikYazi, this.aciklama, {super.key, this.dugme, this.onDugme});
  final String baslikYazi;
  final String aciklama;
  final String? dugme;
  final VoidCallback? onDugme;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(baslikYazi, style: baslik(22), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(aciklama, style: const TextStyle(color: Renk.soluk, height: 1.5), textAlign: TextAlign.center),
              if (dugme != null) ...[
                const SizedBox(height: 20),
                FilledButton(onPressed: onDugme, child: Text(dugme!)),
              ],
            ],
          ),
        ),
      );
}

class HataKutusu extends StatelessWidget {
  const HataKutusu(this.hata, {super.key, this.tekrar});
  final Object hata;
  final VoidCallback? tekrar;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Bir sorun oluştu', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 8),
              Text('$hata', style: const TextStyle(color: uyariRenk), textAlign: TextAlign.center),
              if (tekrar != null) ...[
                const SizedBox(height: 16),
                FilledButton(onPressed: tekrar, child: const Text('Tekrar dene')),
              ],
            ],
          ),
        ),
      );
}

Widget yukleniyor() => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));

Future<bool> onayIste(BuildContext c, String baslikYazi, String metin, String dugme, {bool tehlike = false}) async {
  final r = await showModalBottomSheet<bool>(
    context: c,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(baslikYazi, style: baslik(22)),
            const SizedBox(height: 8),
            Text(metin, style: const TextStyle(color: Renk.soluk, height: 1.5)),
            const SizedBox(height: 20),
            FilledButton(
              style: tehlike ? FilledButton.styleFrom(backgroundColor: Renk.kiremit) : null,
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(dugme),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç'),
            ),
          ],
        ),
      ),
    ),
  );
  return r ?? false;
}
