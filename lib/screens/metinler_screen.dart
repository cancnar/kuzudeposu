import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../data.dart';
import '../theme.dart';
import '../widgets.dart';

/// Hukuki metinler TASLAKTIR: yayından önce avukat incelemesinden geçirilecek (CLAUDE.md eksikler 5–6).
/// [Köşeli parantez] içindeki yerler şirket bilgileriyle doldurulacak.
const _taslakNotu = 'TASLAK · Bu metin yayından önce hukuki incelemeden geçirilecektir.';

typedef MetinBolumu = ({String baslik, String metin});

const kullanimKosullari = <MetinBolumu>[
  (
    baslik: '1. Hizmetin tanımı',
    metin: 'Kuzu Deposu, canlı hayvan alıcı ve satıcılarını buluşturan bir ilan platformudur. Platform satışın tarafı değildir; '
        'hayvanın teslimi, ödemesi, sağlığı ve belgelerinden alıcı ve satıcı sorumludur.'
  ),
  (
    baslik: '2. Üyelik',
    metin: 'Üyelik cep telefonu numarası ve SMS koduyla yapılır. 18 yaşından küçükler üye olamaz. Hesabının güvenliğinden sen sorumlusun; '
        'başkası adına ilan veremezsin.'
  ),
  (
    baslik: '3. İlan kuralları',
    metin: '• İlan, gerçekten sahip olduğun veya satmaya yetkili olduğun hayvan için verilir.\n'
        '• Fotoğraflar ilandaki hayvana ait ve güncel olmalıdır.\n'
        '• Küpe, sağlık ve nakil belgeleri ile ilgili bilgiler doğru olmalıdır; canlı hayvan ticaretine ilişkin mevzuata uymak satıcının sorumluluğundadır.\n'
        '• Açıklamaya veya fotoğrafa IBAN, telefon numarası ya da ön ödeme talebi yazılamaz.\n'
        '• Yasaklı, hasta, karantinadaki veya kaçak hayvan ilanı verilemez.'
  ),
  (
    baslik: '4. Güvenli alışveriş',
    metin: 'Hayvanı yerinde görmeden kapora veya ön ödeme gönderme. Ödemeyi teslimde yap. Şüpheli ilanı ve kullanıcıyı uygulamadan bildir.'
  ),
  (
    baslik: '5. Moderasyon',
    metin: 'Kurallara aykırı ilanlar yönetici tarafından gizlenebilir veya kaldırılabilir; aynı ilanı üç farklı kullanıcı bildirirse ilan otomatik olarak '
        'incelemeye alınır. Kuralları tekrar eden hesaplar askıya alınabilir. Bu durumlarda uygulama içinden bildirim gönderilir.'
  ),
  (
    baslik: '6. Sorumluluğun sınırı',
    metin: 'Platform, kullanıcılar arasındaki alışverişten doğan zararlardan, ilan içeriklerinin doğruluğundan ve hayvanın durumundan sorumlu değildir; '
        'yasal zorunluluklar saklıdır.'
  ),
  (baslik: '7. Değişiklikler', metin: 'Bu koşullar güncellenebilir; önemli değişiklikler uygulama içinde duyurulur.'),
  (baslik: '8. İletişim', metin: '[Şirket unvanı] · [Adres] · [E-posta]. Uygulamadaki "Yardım ve destek > Bize yaz" bölümünden de ulaşabilirsin.'),
];

const kvkkMetni = <MetinBolumu>[
  (
    baslik: 'Veri sorumlusu',
    metin: '6698 sayılı Kişisel Verilerin Korunması Kanunu ("KVKK") kapsamında veri sorumlusu [Şirket unvanı, adres] ("Kuzu Deposu")\'dur.'
  ),
  (
    baslik: 'İşlenen kişisel veriler',
    metin: '• Kimlik ve iletişim: ad soyad, cep telefonu numarası\n'
        '• Konum: profilde ve ilanda seçtiğin il ve ilçe (tam adres alınmaz)\n'
        '• İçerik: ilanlar, fotoğraf ve videolar, alıcı talepleri, mesajlar, teklifler, yorumlar, şikâyetler, destek mesajları, profil fotoğrafı\n'
        '• Kullanım: rastgele üretilmiş cihaz kimliğiyle günlük kullanım sayısı, uygulama tercihleri'
  ),
  (
    baslik: 'İşleme amaçları ve hukuki sebepler',
    metin: 'Üyelik ve giriş, ilan yayınlama, alıcı ile satıcıyı buluşturma, mesajlaşma ve bildirim gönderme amaçlarıyla, KVKK m.5/2-c '
        '(sözleşmenin kurulması ve ifası); dolandırıcılığın önlenmesi, şikâyetlerin incelenmesi ve platform güvenliği amacıyla m.5/2-f '
        '(meşru menfaat); yasal yükümlülükler için m.5/2-ç kapsamında işlenir.'
  ),
  (
    baslik: 'Aktarım',
    metin: 'Veriler, uygulamanın altyapı hizmetini sağlayan bulut sağlayıcısında (Supabase) saklanır ve SMS doğrulaması için SMS sağlayıcısına '
        'telefon numarası iletilir. Yurt dışına aktarım KVKK m.9\'a uygun şekilde yapılır. Yetkili kamu kurumlarının talebi halinde mevzuat '
        'çerçevesinde paylaşım yapılabilir. İlan sayfasında adın, ilçen ve puanın diğer kullanıcılara görünür; telefon numaran gizli kalır.'
  ),
  (
    baslik: 'Saklama süresi',
    metin: 'Veriler hesabın açık olduğu sürece saklanır. "Hesabımı sil" ile hesabın, ilanların, mesajların ve değerlendirmelerin silinir; '
        'yasal saklama yükümlülüğü olan kayıtlar mevzuattaki süre boyunca tutulur.'
  ),
  (
    baslik: 'Hakların (KVKK m.11)',
    metin: 'Verilerinin işlenip işlenmediğini öğrenme, bilgi isteme, düzeltilmesini veya silinmesini isteme, aktarıldığı üçüncü kişileri '
        'bilme, itiraz etme ve zararın giderilmesini talep etme hakların vardır. Başvurunu [e-posta] adresine veya uygulamadaki '
        '"Yardım ve destek > Bize yaz" bölümüne iletebilirsin.'
  ),
];

class MetinScreen extends StatelessWidget {
  const MetinScreen({super.key, required this.baslikYazi, required this.bolumler});
  final String baslikYazi;
  final List<MetinBolumu> bolumler;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(baslikYazi)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Renk.kupe, borderRadius: BorderRadius.circular(10)),
              child: const Text(_taslakNotu, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            for (final b in bolumler) ...[
              const SizedBox(height: 18),
              Semantics(header: true, child: Text(b.baslik, style: baslik(18))),
              const SizedBox(height: 6),
              Text(b.metin, style: const TextStyle(fontSize: 15, height: 1.55)),
            ],
          ],
        ),
      );
}

void kosullariAc(BuildContext c) =>
    Navigator.of(c).push(MaterialPageRoute(builder: (_) => const MetinScreen(baslikYazi: 'Kullanım koşulları', bolumler: kullanimKosullari)));
void kvkkAc(BuildContext c) =>
    Navigator.of(c).push(MaterialPageRoute(builder: (_) => const MetinScreen(baslikYazi: 'KVKK aydınlatma metni', bolumler: kvkkMetni)));

/// "… Kullanım Koşulları ve KVKK Aydınlatma Metni …" — iki bağlantılı metin.
class SartlarMetni extends StatefulWidget {
  const SartlarMetni({super.key, required this.once, required this.sonra, this.stil, this.ortala = false});
  final String once, sonra;
  final TextStyle? stil;
  final bool ortala;
  @override
  State<SartlarMetni> createState() => _SartlarMetniState();
}

class _SartlarMetniState extends State<SartlarMetni> {
  late final _k = TapGestureRecognizer()..onTap = () => kosullariAc(context);
  late final _v = TapGestureRecognizer()..onTap = () => kvkkAc(context);

  @override
  void dispose() {
    _k.dispose();
    _v.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const link = TextStyle(color: Renk.yesil, fontWeight: FontWeight.w800, decoration: TextDecoration.underline);
    return Text.rich(
      TextSpan(style: widget.stil, children: [
        TextSpan(text: widget.once),
        TextSpan(text: 'Kullanım Koşulları', style: link, recognizer: _k),
        const TextSpan(text: ' ve '),
        TextSpan(text: 'KVKK Aydınlatma Metni', style: link, recognizer: _v),
        TextSpan(text: widget.sonra),
      ]),
      textAlign: widget.ortala ? TextAlign.center : TextAlign.start,
    );
  }
}

// ======================= YARDIM VE DESTEK =======================

const _sss = <MetinBolumu>[
  (
    baslik: 'Nasıl ilan veririm?',
    metin: 'Alttaki + düğmesine dokun, "Hayvan satıyorum"u seç. Dört kısa adımda hayvanı, yaş-ağırlık-fiyatı, konumu ve fotoğrafları '
        'gir. En az 3 güncel fotoğraf gerekir.'
  ),
  (
    baslik: 'Kapora istenirse ne yapmalıyım?',
    metin: 'Hayvanı yerinde görmeden kapora veya ön ödeme gönderme. Kapora isteyen ilanı ilan sayfasındaki "Bildir" ile şikâyet et; '
        'üç farklı kişi bildirirse ilan otomatik incelemeye alınır.'
  ),
  (
    baslik: 'Küpe numarasını nasıl kontrol ederim?',
    metin: 'Satıcıdan hayvanın kulak küpesi numarasını iste ve resmi kayıt sisteminden doğrula. İlan sayfasındaki "Satın almadan önce '
        'kontrol et" listesi adım adım yol gösterir.'
  ),
  (
    baslik: 'Teklif nasıl çalışır?',
    metin: 'İlan sayfasında "Teklif ver" ile fiyat önerirsin. Teklifin sohbette kart olarak görünür; satıcı "Kabul et" veya "Reddet" der.'
  ),
  (
    baslik: 'İlanım neden yayında değil?',
    metin: '"İlanlarım"da ilanın üstünde durum yazar: "Onay bekliyor" (yönetici onayı), "İncelemede" (şikâyet), "Yönetici gizledi" '
        'veya süresi dolmuş olabilir. Süresi dolan ilanı ilan sayfasından 30 gün uzatabilirsin.'
  ),
  (baslik: 'Telefon numaram görünür mü?', metin: 'Hayır. Alıcılar adını, ilçeni ve puanını görür; iletişim uygulama içi mesajla olur.'),
  (baslik: 'Hesabımı nasıl silerim?', metin: 'Profil sekmesinin en altındaki "Hesabımı sil" ile; ilanların ve mesajların da silinir.'),
];

class YardimScreen extends StatelessWidget {
  const YardimScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Yardım ve destek')),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text('Sık sorulan sorular', style: TextStyle(color: Renk.soluk, fontWeight: FontWeight.w800)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                decoration: kutu(18),
                clipBehavior: Clip.antiAlias,
                child: Column(children: [
                  for (final s in _sss)
                    ExpansionTile(
                      expansionAnimationStyle: Hareket.acilir(context),
                      shape: const Border(),
                      collapsedShape: const Border(),
                      title: Text(s.baslik, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      expandedAlignment: Alignment.centerLeft,
                      children: [Text(s.metin, style: const TextStyle(height: 1.5))],
                    ),
                ]),
              ),
            ),
            Bolum('', [
              Satir('Bize yaz', ikon: Icons.mail_outline_rounded, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BizeYazScreen()))),
              Satir('Kullanım koşulları', ikon: Icons.description_outlined, onTap: () => kosullariAc(context)),
              Satir('KVKK aydınlatma metni', ikon: Icons.privacy_tip_outlined, onTap: () => kvkkAc(context)),
            ]),
          ],
        ),
      );
}

class BizeYazScreen extends StatefulWidget {
  const BizeYazScreen({super.key});
  @override
  State<BizeYazScreen> createState() => _BizeYazScreenState();
}

class _BizeYazScreenState extends State<BizeYazScreen> {
  String _konu = 'soru';
  final _mesaj = TextEditingController();
  final _iletisim = TextEditingController();
  String? _mesajHata, _hata;
  bool _yuk = false;

  Future<void> _gonder() async {
    final m = _mesaj.text.trim();
    setState(() {
      _mesajHata = m.length < 5 ? 'Birkaç kelimeyle anlat (en az 5 karakter).' : null;
      _hata = null;
    });
    if (_mesajHata != null) return;
    setState(() => _yuk = true);
    try {
      await destekGonder(_konu, m, _iletisim.text);
      if (!mounted) return;
      Navigator.of(context).pop();
      bildir(context, 'Mesajın alındı, teşekkürler. En kısa sürede dönüş yapacağız.');
    } catch (e) {
      setState(() => _hata = 'Gönderilemedi: $e');
    } finally {
      if (mounted) setState(() => _yuk = false);
    }
  }

  @override
  void dispose() {
    _mesaj.dispose();
    _iletisim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Bize yaz')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            const Text('Konu', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Wrap(runSpacing: 8, children: [for (final e in destekKonulari.entries) Cip(e.value, _konu == e.key, () => setState(() => _konu = e.key))]),
            const SizedBox(height: 16),
            TextField(
              controller: _mesaj,
              maxLines: 6,
              maxLength: 2000,
              onChanged: (_) => _mesajHata == null ? null : setState(() => _mesajHata = null),
              decoration: InputDecoration(labelText: 'Mesajın', alignLabelWithHint: true, errorText: _mesajHata),
            ),
            if (uidVarsa == null) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _iletisim,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Sana nasıl ulaşalım? (telefon veya e-posta, isteğe bağlı)'),
              ),
            ],
            if (_hata != null) Text(_hata!, style: const TextStyle(color: uyariRenk, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Basma(
              child: FilledButton(
                onPressed: _yuk ? null : _gonder,
                child: _yuk ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Gönder'),
              ),
            ),
          ],
        ),
      );
}
