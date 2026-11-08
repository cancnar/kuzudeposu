import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

String _norm(String s) => s
    .trim()
    .toLowerCase()
    .replaceAll('İ', 'i')
    .replaceAll('ı', 'i')
    .replaceAll('ş', 's')
    .replaceAll('ğ', 'g')
    .replaceAll('ü', 'u')
    .replaceAll('ö', 'o')
    .replaceAll('ç', 'c');

/// Hayvanın sevki için aranan belgeler (Tarım ve Orman Bakanlığı kurbanlık sevk kuralları).
/// İl içinde: büyükbaşta küpe + pasaport, küçükbaşta küpe + nakil belgesi.
/// İller arasında bunlara veteriner sağlık raporu eklenir.
List<String> gerekliBelgeler(Ilan i, String? aliciIl) {
  final l = <String>[];
  switch (i.tur) {
    case 'buyukbas':
      l.addAll(['kupe', 'pasaport']);
    case 'kucukbas':
      l.addAll(['kupe', 'nakil']);
    case 'at':
      l.add('pasaport');
  }
  final farkliIl = aliciIl != null && aliciIl.trim().isNotEmpty && _norm(aliciIl) != _norm(i.il);
  if (farkliIl && (i.tur == 'buyukbas' || i.tur == 'kucukbas')) l.add('saglik_raporu');
  return l;
}

List<String> eksikBelgeler(Ilan i, String? aliciIl) => gerekliBelgeler(i, aliciIl).where((b) => !i.belgeler.contains(b)).toList();

/// Satıcının güven özeti: yeni üye uyarısı ve satış sayısı.
class SaticiGuven {
  SaticiGuven(this.uyelik, this.satis);
  final DateTime? uyelik;
  final int satis;
  bool get yeni => uyelik != null && DateTime.now().difference(uyelik!).inDays < 30 && satis == 0;
}

class AliciRehberi extends StatelessWidget {
  const AliciRehberi({super.key, required this.ilan, this.aliciIl});
  final Ilan ilan;
  final String? aliciIl;

  @override
  Widget build(BuildContext context) {
    final gerekli = gerekliBelgeler(ilan, aliciIl);
    final eksik = eksikBelgeler(ilan, aliciIl);
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: kutu(18),
      child: Material(
        type: MaterialType.transparency,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          expansionAnimationStyle: Hareket.acilir(context),
          title: const Text('Satın almadan önce kontrol et', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          subtitle: eksik.isEmpty ? null : Text('${eksik.length} belge ilanda belirtilmemiş', style: const TextStyle(color: Renk.kiremit, fontSize: 12.5, fontWeight: FontWeight.w700)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (gerekli.isNotEmpty) ...[
              Text(
                aliciIl != null && gerekli.contains('saglik_raporu') ? 'İller arası sevkte aranan belgeler:' : 'Sevk için aranan belgeler:',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              for (final b in gerekli)
                Text(
                  '${ilan.belgeler.contains(b) ? '✓' : '•'} ${belgeEtiket[b] ?? b}${ilan.belgeler.contains(b) ? '' : '  (ilanda belirtilmemiş, satıcıya sor)'}',
                  style: TextStyle(color: ilan.belgeler.contains(b) ? Renk.yesil : Renk.murekkep, height: 1.5),
                ),
              const SizedBox(height: 10),
            ],
            const Text('Küpe numarasını sorgula: hayvanbilgi.tarim.gov.tr veya TÜRKVET / HaySag uygulaması. Tür, ırk, cinsiyet ve yaş ilanla uyuşmalı.', style: TextStyle(height: 1.45)),
            const SizedBox(height: 10),
            const Text('Hayvanı almayın: burun/salya akıntısı, gözyaşı, zor nefes, öksürük, ishal ya da yem yememe varsa.', style: TextStyle(height: 1.45)),
            const SizedBox(height: 10),
            const Text('Taşıyan aracın dezenfeksiyon belgesi olmalı. Parayı hayvanı teslim alırken öde, kapora gönderme.', style: TextStyle(height: 1.45)),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: 'https://hayvanbilgi.tarim.gov.tr'));
                  bildir(context, 'Küpe sorgulama adresi kopyalandı');
                },
                child: const Text('Sorgulama adresini kopyala'),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
