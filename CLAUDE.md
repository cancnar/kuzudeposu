# Kuzu Deposu – Proje Hafızası

Her yeni oturumda önce bunu oku. Kullanıcı Türkçe konuşur (Salihli/Manisa, iPhone, Europe/Istanbul); yanıtlar Türkçe, kısa, sonuç odaklı olsun.

## Ürün
Türkiye için canlı hayvan (öncelik kuzu/küçükbaş, ayrıca büyükbaş, at) alım-satım mobil uygulaması. Claude ile baştan sona geliştiriliyor. Flutter web, GitHub Pages'te yayınlanıyor (github.com/cancnar/kuzudeposu, branch main) ve iPhone'dan ücretsiz test ediliyor. Backend: Supabase (Postgres + RLS + Auth + Storage + RPC + trigger).

## Marka
Çayır paleti: yeşil #2F5D3A, krem #FBF6E9, kiremit #B2432C, mürekkep #3A3220, çizgi #E3DCC3, soluk #6A5E48, altın #E8C872; ek: kart #FFFDF8, zemin2 #EDE6CF, küpe sarısı #F4E3AE. Fontlar: Fraunces + Nunito. Logo: boynuzlu rozet (yenisi aranıyor). Marka dosyaları: brand/, tool/marka_uygula.py.
- Tasarım kuralları (Emil Kowalski / emil-design-eng yeteneği ile, 8 Kasım 2026): kenarlık yerine gölge (Golge.kart, kutu()), fiyat mürekkep renginde (kiremit sadece uyarı/silme/favori), küpe/belge rozetleri listede görünür, basılabilen her şey Basma ile 0,97'ye küçülür (160 ms, Hareket.cikis = Cubic(0.23,1,0.32,1)), sekme göstergesi 240 ms kayar, alt sayfalar Hareket.altSayfa (iOS çekmece eğrisi), iOS sayfa geçişleri, dalga efekti yok, sık işlerde animasyon yok. Tasarım tuvali: "Kuzu Deposu – Uygulama Tasarımı" artifact'i.
- İsim/logo: "Kuzu Deposu" büyükbaşı dışlıyor; Claude Docs "Uygulama İsim Önerileri"nde kısa liste Toynak (öneri), Küpeli, MeraPazar, Ungula. Alan adı ve TÜRKPATENT kontrolü kullanıcıda. Logo yönü olarak kulak küpesi fikri beğenildi ama çizimler beğenilmedi; isim kesinleşince yeniden.

## Çalışma kuralları / tercihler
- Flutter SDK sandbox'ta kurulamaz; derleme/test sadece GitHub Actions'ta (.github/workflows/web.yml: analiz, 12 test + canlı E2E test/entegrasyon_test.dart, web build, tool/ekran.js ile ekran görüntüleri `ekranlar` branch'ine, Pages deploy). Sonuçlar: `gh api repos/cancnar/kuzudeposu/check-runs/<job>/annotations`. Bir döngü ≈ 3–4 dk.
- SQL'i kullanıcı Supabase SQL Editor'de elle çalıştırır. Claude gizli anahtar tutmaz. Sadece publishable key (sb_publishable_...) kullanılır; `sb_secret_` / `service_role` asla istenmez veya paylaşılmaz.
- SQL sırası: schema, 002, 003_satici_profili, seed_satici_gecmisi, 004_ozellikler, seed_004_ozellikler, 005_guvenlik, 006_talepler, 007_video. 007 dahil hepsi çalışıyor: 8 Kasım 2026 CI'ında canlı video yükleme testi geçti.
- Test hesabı: +905559999999, OTP 123456.
- Kullanıcı araştırmayı döngüyle ister (araştır, güncelle, tekrar araştır, bitince cevap ver). Uzun çıktılar Claude Docs olarak yazılır.

## Yapılanlar
- Temel akış: telefon girişi + OTP, misafir gezinme, ilan listesi/filtre/detay, fotoğraf galerisi, mesajlaşma, bildirim, favori, hesap silme (Apple şartı), KVKK onay kutusu.
- 004: amaç, belgeler, pazarlık, teslimat, görüntülenme; fiyat özeti (piyasa kıyası), ilan istatistiği.
- Alıcı kontrol rehberi (lib/rehber.dart), satıcı güven bilgisi, ilan süresi + uzatma (+30 gün).
- 005: aynı sebeple 3 farklı kişi şikayet ederse ilan otomatik gizlenir (reports trigger).
- 006: alıcı talepleri (wanted_ads), eşleşen satıcılara bildirim, talebe ilan önerme RPC. "+" menüsü: Hayvan satıyorum / Hayvan arıyorum; ana ekranda İlanlar / Alıcı talepleri sekmeleri.
- 007: ilana video (60 sn, 50 MB, bucket listing-videos), lib/video.dart oynatıcı.
- Görsel kimlik düzeltmeleri, PWA ikon/manifest, tema iyileştirmeleri.
- Claude Docs: "Pazar Araştırması Güncellemesi" ve "Türkiye Rakip Analizi" (potansiyel müşteri bölümü dahil).

## Rakip analizi özeti
Türkiye'de baskın, güven odaklı, hayvana özel mobil pazar yeri yok. Rakipler: CanlıPazar (5.000+ indirme), CelepPazarı (web), Haydy (10+ indirme), BesiNet, Hayvanım Cebimde, sahibinden.com, devlet araçları (TÜRKVET), WhatsApp/Telegram/Facebook grupları. Farkımız: belge/küpe rehberi, satıcı güveni, şikayetle gizleme, fiyat kıyası, alıcı talepleri, video. Pazar: ~2 milyon kayıtlı işletme; düzenli dijital kullanıcı varsayımı %10–20 (doğrulanmadı).

## Eksikler / sıradaki işler
1. İsim kararı → logo → ikon/manifest güncellemesi. İlan verme formunu 4 adımlı akışa bölmek (tasarımda var, kodda yok). Test ilanlarından birinde kişi adı + IBAN içeren fotoğraf var, silinmeli.
2. Gerçek SMS sağlayıcı (şu an sadece test numarası).
3. KVKK aydınlatma metni ve kullanım şartları (yer tutucu); mağaza metinleri, gizlilik politikası.
4. Avukat görüşü: canlı hayvanın online satışı, Canlı Hayvan Ticareti Satıcıları yönetmeliği.
5. Push bildirim (FCM), harita/yakınlık sıralaması, video dönüştürme (iPhone .mov uyumu).
6. Moderasyon paneli, ilk ilanlar için tohum içerik stratejisi, kapora/ödeme koruması fikri.
7. Depo herkese açık (kullanıcı özel istedi, ama Pages özel depoda ücretli). Apple/Google geliştirici hesapları. iPhone gerçek cihaz testi.
