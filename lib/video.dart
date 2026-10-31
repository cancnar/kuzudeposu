import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'theme.dart';

/// Tam ekran video oynatıcı (dokununca oynat / durdur).
class VideoEkrani extends StatefulWidget {
  const VideoEkrani({super.key, required this.url});
  final String url;

  @override
  State<VideoEkrani> createState() => _VideoEkraniState();
}

class _VideoEkraniState extends State<VideoEkrani> {
  late final VideoPlayerController _c = VideoPlayerController.networkUrl(Uri.parse(widget.url));
  bool _hazir = false;
  Object? _hata;

  @override
  void initState() {
    super.initState();
    _c.initialize().then((_) {
      if (!mounted) return;
      setState(() => _hazir = true);
      _c.play();
    }).catchError((Object e) {
      if (mounted) setState(() => _hata = e);
    });
    _c.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _degistir() => _c.value.isPlaying ? _c.pause() : _c.play();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: const Text('Video', style: TextStyle(color: Colors.white))),
      body: Center(
        child: _hata != null
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Video oynatılamadı. Tarayıcın bu video biçimini desteklemiyor olabilir.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white)),
              )
            : !_hazir
                ? const CircularProgressIndicator(color: Colors.white)
                : GestureDetector(
                    onTap: _degistir,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AspectRatio(aspectRatio: _c.value.aspectRatio, child: VideoPlayer(_c)),
                        if (!_c.value.isPlaying)
                          Container(
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            padding: const EdgeInsets.all(14),
                            child: const Icon(Icons.play_arrow, color: Colors.white, size: 44),
                          ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: VideoProgressIndicator(_c, allowScrubbing: true, colors: const VideoProgressColors(playedColor: Renk.kiremit, bufferedColor: Colors.white30, backgroundColor: Colors.white12)),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}
