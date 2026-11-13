import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'data.dart' show uidVarsa;
import 'models.dart';
import 'theme.dart';

TextStyle baslik(double boyut, {Color? renk}) =>
    GoogleFonts.fraunces(fontSize: boyut, fontWeight: FontWeight.w700, color: renk ?? Renk.murekkep);

const altin = Color(0xFFE8C872);
const yildizRenk = Color(0xFF7A5200);
const acikYesil = Renk.okZemin;
const uyariRenk = Color(0xFFA32D2D);

/// Kenarlık yerine gölgeli kart yüzeyi.
BoxDecoration kutu([double yaricap = 18, List<BoxShadow> golge = Golge.kart]) =>
    BoxDecoration(color: Renk.kart, borderRadius: BorderRadius.circular(yaricap), boxShadow: golge);

void bildir(BuildContext c, String m) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 3)));
}

/// Basılabilen her şey parmak değince 0,97'ye küçülür (160 ms, güçlü ease-out).
/// "Hareketi azalt" açıksa küçülme yapılmaz.
class Basma extends StatefulWidget {
  const Basma({super.key, required this.child, this.olcek = 0.97, this.etkin = true});
  final Widget child;
  final double olcek;
  final bool etkin;
  @override
  State<Basma> createState() => _BasmaState();
}

class _BasmaState extends State<Basma> {
  bool _basili = false;
  void _ayarla(bool b) {
    if (_basili != b && mounted) setState(() => _basili = b);
  }

  @override
  Widget build(BuildContext context) {
    final azalt = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final kucuk = widget.etkin && !azalt && _basili;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _ayarla(true),
      onPointerUp: (_) => _ayarla(false),
      onPointerCancel: (_) => _ayarla(false),
      child: AnimatedScale(
        scale: kucuk ? widget.olcek : 1,
        duration: Hareket.basma,
        curve: Hareket.cikis,
        child: widget.child,
      ),
    );
  }
}

/// Küçük bilgi rozeti (küpe, belge, amaç).
class Rozet extends StatelessWidget {
  const Rozet(this.yazi, {super.key, this.tur = RozetTuru.duz, this.kucuk = false});
  final String yazi;
  final RozetTuru tur;
  final bool kucuk;
  @override
  Widget build(BuildContext context) {
    final (zemin, yaziRenk, ikon) = switch (tur) {
      RozetTuru.kupe => (Renk.kupe, Renk.murekkep, Icons.sell_outlined),
      RozetTuru.ok => (Renk.okZemin, Renk.okYazi, Icons.check),
      RozetTuru.duz => (Renk.zemin2, Renk.murekkep, null),
    };
    final boy = kucuk ? 12.0 : 13.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: kucuk ? 8 : 10, vertical: kucuk ? 3 : 5),
      decoration: BoxDecoration(color: zemin, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (ikon != null) ...[Icon(ikon, size: boy + 1, color: yaziRenk), const SizedBox(width: 4)],
          Flexible(child: Text(yazi, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: boy, fontWeight: FontWeight.w800, color: yaziRenk))),
        ],
      ),
    );
  }
}

enum RozetTuru { kupe, ok, duz }

/// Fotoğrafın üstünde duran yuvarlak buton (geri, favori).
/// İkon değişince (ör. favoriye eklenince) 160 ms ölçek + solma ile yer değiştirir;
/// "Hareketi azalt" açıksa yalnızca solma. [titresim] dokununca hafif titreşim verir.
class YuzenDugme extends StatelessWidget {
  const YuzenDugme({super.key, required this.ikon, required this.ipucu, required this.onPressed, this.renk = Renk.murekkep, this.titresim = false});
  final IconData ikon;
  final String ipucu;
  final VoidCallback? onPressed;
  final Color renk;
  final bool titresim;
  @override
  Widget build(BuildContext context) {
    final azalt = Hareket.azalt(context);
    final cb = onPressed;
    return Basma(
      olcek: 0.92,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: Renk.kart.withValues(alpha: 0.92), shape: BoxShape.circle, boxShadow: Golge.yuzen),
        child: IconButton(
          tooltip: ipucu,
          padding: EdgeInsets.zero,
          onPressed: cb == null
              ? null
              : () {
                  if (titresim) HapticFeedback.lightImpact();
                  cb();
                },
          icon: AnimatedSwitcher(
            duration: Hareket.basma,
            switchInCurve: Hareket.cikis,
            switchOutCurve: Curves.easeOut,
            transitionBuilder: (child, anim) => azalt
                ? FadeTransition(opacity: anim, child: child)
                : FadeTransition(opacity: anim, child: ScaleTransition(scale: Tween(begin: 0.8, end: 1.0).animate(anim), child: child)),
            child: Icon(ikon, key: ValueKey(ikon), color: renk, size: 22),
          ),
        ),
      ),
    );
  }
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

/// Seçim çipi: seçiliyken yeşil dolgu; renk geçişi 180 ms, basınca küçülür.
class Cip extends StatelessWidget {
  const Cip(this.yazi, this.secili, this.onTap, {super.key});
  final String yazi;
  final bool secili;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8, top: 3, bottom: 3),
        child: Semantics(
          button: true,
          selected: secili,
          label: yazi,
          excludeSemantics: true,
          onTap: onTap,
          child: Basma(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: AnimatedContainer(
                duration: Hareket.renk,
                curve: Curves.ease,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: secili ? Renk.yesil : Renk.kart,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: Golge.hafif,
                ),
                child: Text(
                  yazi,
                  style: TextStyle(color: secili ? Renk.krem : Renk.murekkep, fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ),
          ),
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
      color: const Color(0xFFE9E2CB),
      alignment: Alignment.center,
      child: Opacity(opacity: .45, child: Logo(boyut: yukseklik > 90 ? 52 : 30)),
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

class _FotoEtiket extends StatelessWidget {
  const _FotoEtiket(this.yazi, {this.zemin = altin, this.yaziRenk = Renk.murekkep, this.ikon});
  final String yazi;
  final Color zemin;
  final Color yaziRenk;
  final IconData? ikon;
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(ikon == null ? 10 : 8, 5, 10, 5),
        decoration: BoxDecoration(color: zemin, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (ikon != null) ...[Icon(ikon, color: yaziRenk, size: 15), const SizedBox(width: 3)],
          Text(yazi, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: yaziRenk)),
        ]),
      );
}

class IlanKarti extends StatelessWidget {
  const IlanKarti({super.key, required this.ilan, required this.onTap, required this.favori, required this.onFavori, this.durumGoster = false, this.kalp = true});
  final Ilan ilan;
  final VoidCallback onTap;
  final bool favori;
  final VoidCallback onFavori;
  final bool durumGoster;
  final bool kalp;

  @override
  Widget build(BuildContext context) {
    final i = ilan;
    final alt = i.suru
        ? '${i.adet} baş · ${i.yasMetni} · ort. ${sayi(i.agirlik)} kg'
        : '${i.yasMetni} · ${sayi(i.agirlik)} kg';
    final kupeli = i.belgeler.contains('kupe');
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Basma(
        olcek: 0.985,
        child: Container(
          decoration: kutu(18),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        // Fotoğrafsız ilanda büyük boş kutu yerine kısa bir şerit (listede daha çok ilan görünür)
                        FotoKutusu(url: i.foto.isEmpty ? null : i.foto.first, yukseklik: i.foto.isEmpty ? 96 : 190, yaricap: 13),
                        if (i.suru) Positioned(left: 10, top: 10, child: _FotoEtiket('Sürü · ${i.adet} baş')),
                        if (i.videoVar)
                          const Positioned(
                            left: 10,
                            bottom: 10,
                            child: _FotoEtiket('Video', zemin: Color(0x9E1C180F), yaziRenk: Colors.white, ikon: Icons.play_arrow_rounded),
                          ),
                        if (durumGoster && !i.aktif)
                          Positioned(
                            right: 10,
                            bottom: 10,
                            child: _FotoEtiket(
                              i.moderasyonAd ?? (i.durum == 'satildi' ? (i.satildiAt != null ? 'Satıldı · ${goreli(i.satildiAt!)}' : 'Satıldı') : 'Yayında değil'),
                              zemin: Renk.murekkep,
                              yaziRenk: Colors.white,
                            ),
                          ),
                        // Kendi ilanını favorilemek anlamsız: kalp yalnızca başkasının ilanında.
                        if (kalp && i.saticiId != uidVarsa)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: YuzenDugme(
                              ikon: favori ? Icons.favorite : Icons.favorite_border,
                              ipucu: favori ? 'Favorilerden çıkar' : 'Favorilere ekle',
                              onPressed: onFavori,
                              renk: Renk.kiremit,
                              titresim: true,
                            ),
                          ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 10, 6, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Expanded(child: Text('${i.cins} (${i.cinsiyetAd.toLowerCase()})', style: baslik(19), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              const SizedBox(width: 10),
                              Text(tl(i.toplam), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Renk.murekkep, fontFeatures: [FontFeature.tabularFigures()])),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text('$alt · ${sayi(i.kgFiyat)} ₺/kg', style: const TextStyle(color: Renk.soluk, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.place_outlined, size: 16, color: Renk.soluk),
                              const SizedBox(width: 3),
                              Expanded(child: Text(i.yer, style: const TextStyle(color: Renk.soluk, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                              if (kupeli) ...[const Rozet('Küpeli', tur: RozetTuru.kupe, kucuk: true), const SizedBox(width: 8)],
                              Text(
                                i.saticiPuanSayisi > 0 ? '★ ${puanYaz(i.saticiPuan)}' : 'Yeni satıcı',
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
            ),
          ),
        ),
      ),
    );
  }
}

/// Başlıklı, gölgeli satır grubu (ayarlar, profil menüsü).
class Bolum extends StatelessWidget {
  const Bolum(this.baslikYazi, this.cocuklar, {super.key});
  final String baslikYazi;
  final List<Widget> cocuklar;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (baslikYazi.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                child: Text(baslikYazi, style: const TextStyle(color: Renk.soluk, fontWeight: FontWeight.w800, fontSize: 13)),
              ),
            Container(
              decoration: kutu(18),
              clipBehavior: Clip.antiAlias,
              child: Column(children: cocuklar),
            ),
          ],
        ),
      );
}

class Satir extends StatelessWidget {
  const Satir(this.yazi, {super.key, this.deger, this.onTap, this.renk, this.ikon});
  final String yazi;
  final String? deger;
  final VoidCallback? onTap;
  final Color? renk;
  final IconData? ikon;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Renk.ayrac))),
          child: Row(
            children: [
              if (ikon != null) ...[Icon(ikon, size: 22, color: renk ?? Renk.yesil), const SizedBox(width: 12)],
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Renk.ayrac))),
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
              const Opacity(opacity: .5, child: Logo(boyut: 52)),
              const SizedBox(height: 14),
              Text(baslikYazi, style: baslik(22), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(aciklama, style: const TextStyle(color: Renk.soluk, height: 1.5), textAlign: TextAlign.center),
              if (dugme != null) ...[
                const SizedBox(height: 20),
                Basma(child: FilledButton(onPressed: onDugme, child: Text(dugme!))),
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
    sheetAnimationStyle: Hareket.altSayfa(c),
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
            Basma(
              child: FilledButton(
                style: tehlike ? FilledButton.styleFrom(backgroundColor: Renk.kiremit, foregroundColor: Colors.white) : null,
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(dugme),
              ),
            ),
            const SizedBox(height: 10),
            Basma(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Vazgeç'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return r ?? false;
}
