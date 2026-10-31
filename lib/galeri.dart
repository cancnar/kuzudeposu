import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Ekran genişliğine oranlı (4:3) kaydırılabilir fotoğraf galerisi.
/// Dokununca tam ekran görüntüleyici açılır.
class FotoGaleri extends StatefulWidget {
  const FotoGaleri({super.key, required this.fotolar, this.saglayici});
  final List<String> fotolar;

  /// Testlerde ağ yerine bellekteki görüntü vermek için.
  final ImageProvider Function(String url)? saglayici;

  @override
  State<FotoGaleri> createState() => _FotoGaleriState();
}

class _FotoGaleriState extends State<FotoGaleri> {
  final _c = PageController();
  int _i = 0;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  ImageProvider _sag(String u) => widget.saglayici != null ? widget.saglayici!(u) : NetworkImage(u);

  Widget _bos() => Container(
        color: Renk.cizgi,
        alignment: Alignment.center,
        child: Icon(Icons.pets, size: 48, color: Renk.soluk.withOpacity(.5)),
      );

  void _git(int p) {
    if (p < 0 || p >= widget.fotolar.length) return;
    _c.animateToPage(p, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.fotolar;
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: f.isEmpty
          ? _bos()
          : Stack(
              fit: StackFit.expand,
              children: [
                ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(dragDevices: {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                    PointerDeviceKind.stylus,
                  }),
                  child: PageView.builder(
                    controller: _c,
                    itemCount: f.length,
                    onPageChanged: (p) => setState(() => _i = p),
                    itemBuilder: (_, n) => GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(fullscreenDialog: true, builder: (_) => FotoGoruntuleyici(fotolar: f, baslangic: n, saglayici: widget.saglayici)),
                      ),
                      child: Image(
                        image: ResizeImage(_sag(f[n]), width: 1200, policy: ResizeImagePolicy.fit),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        gaplessPlayback: true,
                        loadingBuilder: (c, w, p) => p == null ? w : Container(color: Renk.cizgi, alignment: Alignment.center, child: const CircularProgressIndicator()),
                        errorBuilder: (_, __, ___) => _bos(),
                      ),
                    ),
                  ),
                ),
                if (f.length > 1) ...[
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                      child: Text('${_i + 1}/${f.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 14,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var n = 0; n < f.length; n++)
                          Container(
                            width: n == _i ? 18 : 7,
                            height: 7,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(color: n == _i ? Colors.white : Colors.white54, borderRadius: BorderRadius.circular(4)),
                          ),
                      ],
                    ),
                  ),
                  if (_i > 0)
                    Positioned(
                      left: 6,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: IconButton.filledTonal(
                          tooltip: 'Önceki fotoğraf',
                          style: IconButton.styleFrom(backgroundColor: Colors.white70),
                          onPressed: () => _git(_i - 1),
                          icon: const Icon(Icons.chevron_left),
                        ),
                      ),
                    ),
                  if (_i < f.length - 1)
                    Positioned(
                      right: 6,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: IconButton.filledTonal(
                          tooltip: 'Sonraki fotoğraf',
                          style: IconButton.styleFrom(backgroundColor: Colors.white70),
                          onPressed: () => _git(_i + 1),
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}

/// Tam ekran, yakınlaştırılabilir fotoğraf görüntüleyici.
class FotoGoruntuleyici extends StatefulWidget {
  const FotoGoruntuleyici({super.key, required this.fotolar, this.baslangic = 0, this.saglayici});
  final List<String> fotolar;
  final int baslangic;
  final ImageProvider Function(String url)? saglayici;

  @override
  State<FotoGoruntuleyici> createState() => _FotoGoruntuleyiciState();
}

class _FotoGoruntuleyiciState extends State<FotoGoruntuleyici> {
  late final PageController _c = PageController(initialPage: widget.baslangic);
  late int _i = widget.baslangic;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_i + 1}/${widget.fotolar.length}', style: const TextStyle(color: Colors.white, fontSize: 16)),
        leading: IconButton(tooltip: 'Kapat', icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
      ),
      body: PageView.builder(
        controller: _c,
        itemCount: widget.fotolar.length,
        onPageChanged: (p) => setState(() => _i = p),
        itemBuilder: (_, n) {
          final u = widget.fotolar[n];
          return InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Center(
              child: Image(
                image: ResizeImage(widget.saglayici != null ? widget.saglayici!(u) : NetworkImage(u), width: 2000, policy: ResizeImagePolicy.fit),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white54, size: 64),
              ),
            ),
          );
        },
      ),
    );
  }
}
