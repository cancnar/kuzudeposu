import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

/// İlanın herkese açık bağlantısı. Açan kişi giriş yapmadan doğrudan ilanı görür (main.dart ?ilan=).
String ilanBaglantisi(String id) {
  if (kIsWeb && Uri.base.host.isNotEmpty && Uri.base.host != 'localhost') {
    return Uri.base.replace(queryParameters: {'ilan': id}, fragment: '').toString().replaceAll('#', '');
  }
  return 'https://cancnar.github.io/kuzudeposu/?ilan=$id';
}

String ilanPaylasimMetni(Ilan i) =>
    '${i.cins} · ${i.adet} baş · ${tl(i.toplam)} · ${i.yer}\n${ilanBaglantisi(i.id)}';

/// Paylaş alt sayfası: WhatsApp, bağlantıyı kopyala.
Future<void> ilanPaylas(BuildContext context, Ilan i) {
  final metin = ilanPaylasimMetni(i);
  var kopyaHata = false;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Renk.krem,
    sheetAnimationStyle: Hareket.altSayfa(context),
    builder: (c) => StatefulBuilder(builder: (c, yenile) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 12), child: Text('İlanı paylaş', style: baslik(22))),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Renk.zemin2, borderRadius: BorderRadius.circular(12)),
            child: SelectableText(metin, style: const TextStyle(height: 1.4)),
          ),
          const SizedBox(height: 12),
          Basma(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1F7A4D)),
              onPressed: () async {
                Navigator.pop(c);
                final ok = await launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(metin)}'), mode: LaunchMode.externalApplication);
                if (!ok && context.mounted) bildir(context, 'WhatsApp açılamadı; bağlantıyı kopyalayıp paylaşabilirsin.');
              },
              icon: const Icon(Icons.chat_rounded),
              label: const Text("WhatsApp'ta paylaş"),
            ),
          ),
          const SizedBox(height: 10),
          Basma(
            child: OutlinedButton.icon(
              onPressed: () async {
                try {
                  await Clipboard.setData(ClipboardData(text: metin));
                } catch (_) {
                  // Tarayıcı panoya yazmaya izin vermediyse sayfayı kapatma: kullanıcı yukarıdaki metni elle seçebilir.
                  yenile(() => kopyaHata = true);
                  return;
                }
                if (c.mounted) Navigator.pop(c);
                if (context.mounted) bildir(context, 'Bağlantı kopyalandı');
              },
              icon: const Icon(Icons.link_rounded),
              label: const Text('Bağlantıyı kopyala'),
            ),
          ),
          if (kopyaHata)
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 10, 4, 0),
              child: Text('Kopyalanamadı. Yukarıdaki bağlantıyı basılı tutup kopyalayabilirsin.', style: TextStyle(color: Renk.kiremit, fontWeight: FontWeight.w700)),
            ),
        ]),
      ),
    )),
  );
}
