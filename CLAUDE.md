# Kuzu Deposu – Proje Hafızası

Her yeni oturumda önce bunu oku. Kullanıcı Türkçe konuşur (Salihli/Manisa, iPhone, Europe/Istanbul); yanıtlar Türkçe, kısa, sonuç odaklı olsun. Kullanıcı sohbetleri silebilir: alınan her kalıcı karar ve kural bu dosyaya yazılır.

## Ürün
Türkiye için canlı hayvan (öncelik kuzu/küçükbaş, ayrıca büyükbaş, at) alım-satım mobil uygulaması. Claude ile baştan sona geliştiriliyor. Flutter web, GitHub Pages'te yayınlanıyor (github.com/cancnar/kuzudeposu, branch main) ve iPhone'dan ücretsiz test ediliyor. Backend: Supabase (Postgres + RLS + Auth + Storage + RPC + trigger).

## Çalışma kuralları / tercihler
- Flutter SDK sandbox'ta kurulamaz; derleme/test sadece GitHub Actions'ta (.github/workflows/web.yml: analiz, 13 test + canlı E2E test/entegrasyon_test.dart, web build, tool/ekran.js ile ekran görüntüleri `ekranlar` branch'ine, Pages deploy). Workflow yalnızca `main`'e push'ta çalışır; değişiklikler doğrudan main'e push edilir (kullanıcı bunu bekliyor). Sonuçlar: `gh run list -R cancnar/kuzudeposu`, `gh api repos/cancnar/kuzudeposu/check-runs/<job>/annotations`. Bir döngü ≈ 4–5 dk (kuyruk olursa daha uzun).
- Her UI değişikliğinden sonra `ekranlar` branch'ini klonlayıp ekran görüntülerine bakılır; görünen hata düzeltilip tekrar push edilir. Push sonrası kullanıcıya CI sonucu (test sayısı) bildirilir.
- Commit mesajları Türkçe; sonunda Co-Authored-By / Claude-Session satırları.
- tool/ekran.js ve testler metinlere dayanır; bu metinler/öğeler DEĞİŞTİRİLMEZ (değişirse ekran.js de güncellenir): "Giriş yapmadan ilanlara göz at", "Telefon numaram ile devam et", "İlanlar", "Alıcı talepleri", filtre butonu tooltip'i "Filtre", "Temizle", "ilanı göster", "Telefon numaram ile giriş yap", "Kodu gönder", "Doğrula", "Başla", "Hayvan satıyorum", "Hayvan arıyorum", "İlanlarım", "Ayarlar", "Kayıtlı aramalarım", "Satın almadan önce kontrol et", ilan kartında "Video", talep kartında "İlanımı öner"/"Talebi kapat", galeri "1/3" sayacı ve "Sonraki fotoğraf"/"Kapat" tooltip'leri. Alt menünün ortası (x=195) "+" menüsünü açar; ilk ilan kartı y≈380'de olmalı.
- SQL'i kullanıcı Supabase SQL Editor'de elle çalıştırır. Claude gizli anahtar tutmaz. Sadece publishable key (sb_publishable_...) kullanılır; `sb_secret_` / `service_role` asla istenmez veya paylaşılmaz.
- SQL sırası: schema, 002, 003_satici_profili, seed_satici_gecmisi, 004_ozellikler, seed_004_ozellikler, 005_guvenlik, 006_talepler, 007_video, 008_yonetici. 007 dahil hepsi çalışıyor (8 Kasım 2026 CI'ında canlı video yükleme testi geçti). 008 (12 Kasım) kullanıcı tarafından henüz çalıştırılmadıysa entegrasyon testi o adımı atlar.
- SQL'i göndermeden önce sandbox'ta yerel PostgreSQL 16 ile dene: /usr/lib/postgresql/16/bin/initdb (postgres kullanıcısıyla), /tmp/pgstub.sql benzeri sahte auth/storage şeması + auth.uid() = current_setting('test.uid'), sonra tüm dosyaları sırayla çalıştır.
- Test hesabı: +905559999999, OTP 123456.
- Kullanıcı araştırmayı döngüyle ister (araştır, güncelle, tekrar araştır, bitince cevap ver). Uzun çıktılar Claude Docs olarak yazılır.
- Görsel üretimde (logo, çizim) yayınlamadan önce SVG'yi `rsvg-convert` ile PNG'ye çevirip kendin bak; görmeden yayınlama. Tasarım seçenekleri "Design" artifact tuvallerinde sunulur.
- Yetenek (skill) kurulumu: depo klonlanır, SKILL.md baştan sona okunur, propose_skills kartı ile önerilir (tek kartta en fazla 3); çok yetenekli depolarda kullanıcıya hangilerini istediği sorulur. Kurulu yetenekler: emil-design-eng (emilkowalski/skills), hig-foundations (raintree-technology/hig-doctor; referans dosyaları kurulu değil, GitHub'dan okunur).

## Marka
Çayır paleti: yeşil #2F5D3A, krem #FBF6E9, kiremit #B2432C, mürekkep #3A3220, çizgi #E3DCC3, soluk #6A5E48, altın #E8C872; ek: kart #FFFDF8, zemin2 #EDE6CF, küpe sarısı #F4E3AE, olumlu zemin #E3ECDA / yazı #24492D. Fontlar: Fraunces (başlık) + Nunito (gövde). Logo: boynuzlu rozet (lib/widgets.dart Logo; geçici). Marka dosyaları: brand/, tool/marka_uygula.py.
- İsim: "Kuzu Deposu" büyükbaşı dışlıyor, değişecek. Claude Docs "Uygulama İsim Önerileri" kısa listesi: Toynak (öneri; koyun, keçi, sığır, manda, at hepsi toynaklı), Küpeli, MeraPazar, Ungula. Slogan önerisi: "Kuzudan tosuna, güvenle al, güvenle sat." Kaçınılacak: Sürü/Sürüm (SürüPlus vb. dolu), Küpe ("Küpe Sorgulama" uygulaması var), Celep (CelepPazarı), Otlak ("otlakçı" argosu), Kantar (küresel Kantar şirketi). Aynı sektörde kuzu.co ("Kuzu Fabrikası") var. Alan adı ve TÜRKPATENT kontrolü kullanıcıda; karar verilmedi.
- Logo: ERTELENDİ (8 Kasım 2026). Denenip beğenilmeyenler: 6 ilk yön (koç rozeti, yün bulutu, ahır kapısı, K monogramı, kulak küpesi, pazar mührü), küpe varyasyonları, kulak+küpe varyasyonları, gerçekçi gravür çizimleri (koç profili, önden koç, önden sığır, koç+sığır mührü). Kullanıcı kendisi açmadan logo önerme.

## Tasarım ve hareket kuralları (8 Kasım 2026; emil-design-eng + Apple HIG)
- Yüzey: kenarlık yerine katmanlı yarı saydam gölge (`Golge.kart`, `Golge.hafif`, `kutu(yaricap)`); kartlar 18 px köşe, zemin krem. Dolgulu ikincil buton (zemin2), çizgili buton yok. Dalga (ripple) efekti yok (`NoSplash`).
- Renk anlamı: fiyat mürekkep renginde ve kalın; kiremit yalnızca uyarı, silme, favori ve okunmamış rozeti. Güven (küpe, belge, satıcı puanı) listede de görünür: `Rozet(..., tur: RozetTuru.kupe/ok/duz)`.
- Dokunma: basılabilen her şey `Basma` ile 0,97'ye küçülür (160 ms, `Hareket.cikis` = Cubic(0.23, 1, 0.32, 1)); hedefler en az 44 px; ikon butonlarında tooltip/semantics etiketi.
- Hareket: sık yapılan işlerde animasyon yok (alt menü sekmeleri, arama, filtre sonuçları, liste kaydırma). Sekme göstergesi (`KayanSekme`) 240 ms kayar, içerik anında değişir. Çip rengi 180 ms ease. Alt sayfalar `sheetAnimationStyle: Hareket.altSayfa(context)` (açılış 320 ms iOS çekmece eğrisi Cubic(0.32, 0.72, 0, 1), kapanış 200 ms); yeni her `showModalBottomSheet` bunu kullanmalı. Açılır bölümler `Hareket.acilir(context)`. Sayfa geçişleri `KuzuSayfaGecisi` (iOS kayması, kenardan geri kaydırma). Favori kalbi `YuzenDugme(titresim: true)`: 160 ms ölçek+solma, hafif titreşim. Asla ease-in, asla scale(0)'dan giriş, UI animasyonları 300 ms altında.
- Hareketi azalt (HIG: hareket isteğe bağlı): `Hareket.azalt(context)` = sistem ayarı VEYA Ayarlar > Görünüm > "Hareketi azalt" (`app.tercih['azalt']`, main.dart MediaQuery'ye işlenir). Açıkken kayma/ölçek yok; sayfa geçişi solma, alt sayfa animasyonsuz, galeri atlar. Yeni animasyon eklerken bu kontrol edilir.
- Ortak bileşenler (lib/widgets.dart, lib/theme.dart): Renk, Hareket, Golge, kutu(), Basma, Rozet, YuzenDugme, Cip, IlanKarti, Bolum (gölgeli grup) + Satir(ikon:), AnahtarSatir, Bos, onayIste; home_screen.dart'ta KayanSekme.
- Tuvaller (Claude artifact'leri): "Kuzu Deposu – Uygulama Tasarımı" (tasarım dili panosu + 8 ekran: karşılama, ana sayfa, detay, + menüsü, ilan ver adım 1/4, talepler, sohbet, profil) ve "Kuzu Deposu – Logo Seçenekleri" (rakip taraması + tüm logo denemeleri).

## Yapılanlar
- Temel akış: telefon girişi + OTP, misafir gezinme, ilan listesi/filtre/detay, fotoğraf galerisi, mesajlaşma, bildirim, favori, hesap silme (Apple şartı), KVKK onay kutusu.
- 004: amaç, belgeler, pazarlık, teslimat, görüntülenme; fiyat özeti (piyasa kıyası), ilan istatistiği.
- Alıcı kontrol rehberi (lib/rehber.dart), satıcı güven bilgisi, ilan süresi + uzatma (+30 gün).
- 005: aynı sebeple 3 farklı kişi şikayet ederse ilan otomatik gizlenir (reports trigger).
- 006: alıcı talepleri (wanted_ads), eşleşen satıcılara bildirim, talebe ilan önerme RPC. "+" menüsü: Hayvan satıyorum / Hayvan arıyorum; ana ekranda İlanlar / Alıcı talepleri sekmeleri.
- 007: ilana video (60 sn, 50 MB, bucket listing-videos), lib/video.dart oynatıcı.
- 8 Kasım 2026 yeni tasarım (kod): gölgeli kartlar, büyük fotoğraflı ilan kartı + Küpeli rozeti, kayan sekme, ikonlu filtre, detayda yüzen butonlar + fotoğraf üstünde video + fiyat aralığı çubuğu + tek "Bilgiler" listesi, yeni alt menü / + menüsü / karşılama / profil; HIG hareket düzeltmeleri ve "Hareketi azalt".
- 008 yönetici paneli (12 Kasım 2026): `admins` tablosu (RLS, politika yok; sadece security definer fonksiyonlar okur), `yonetici_mi()`, `yonetici_ozet()` (yönetici değilse 'yetki yok' hatası), `app_visits` + `ziyaret_kaydet(cihaz, platform)` (anonim cihaz kimliği, günde 1 kayıt, misafirler dahil; localhost açılışları sayılmaz), `ornek_hesap(uuid)` (aaaaaaaa-/cccccccc- örnek hesaplar tüm sayılardan hariç). Uygulama: lib/screens/admin_screen.dart (YoneticiScreen; Kullanım/Üyeler/İlanlar/Etkileşim kartları, son 14 gün grafiği, tür/il/rol oranları), Profil'de sadece yöneticiye "Yönetici paneli" satırı (app.yonetici). Yerel önizleme: localhost/?onizleme=yonetici örnek veriyle (ekran.js yonetici_1..5 görüntüleri). Yönetici eklemek: `insert into public.admins (user_id) select id from auth.users where phone = '905XXXXXXXXX';` Test numarası ASLA yönetici yapılmaz (kodu depoda açık).
- Claude Docs: "Kuzu Deposu – Reklam Planı 2027" (8 Kasım; TikTok canlı hayvan reklamını yasaklıyor, Meta P2P hayvan satışı reklamını yasaklıyor → Google ağırlıklı plan).
- Claude Docs: "Pazar Araştırması Güncellemesi", "Türkiye Rakip Analizi" (potansiyel müşteri bölümü dahil), "Uygulama İsim Önerileri".

## Rakip analizi özeti
Türkiye'de baskın, güven odaklı, hayvana özel mobil pazar yeri yok. Yerli: CanlıPazar (5.000+ indirme), HayvanBurada (Afyon, web; yem/araç/hizmet ilanları, küpe barkodu hedefi), CelepPazarı (web), Haydy, BesiNet, Hayvanım Cebimde, sahibinden.com, devlet araçları (TÜRKVET), WhatsApp/Telegram/Facebook grupları. Yabancı: AuctionsPlus (Avustralya, logosu A+ inek başı), SellMyLivestock (İngiltere, 170.000+ çiftçi), LivestockMarket (ABD, "Want-to-Buy" = bizim alıcı talebi), Breedr, FarmGate Auctions, Pashu Mandi/BharatCattle. Sektörde ana motif sığır başı; kuzu/koç kullanan güçlü marka yok. Farkımız: belge/küpe rehberi, satıcı güveni, şikayetle gizleme, fiyat kıyası, alıcı talepleri, video. Pazar: ~2 milyon kayıtlı işletme; düzenli dijital kullanıcı varsayımı %10–20 (doğrulanmadı).

## Eksikler / sıradaki işler
1. Test ilanlarından birinin fotoğrafında kişi adı + IBAN var (Holstein, Kula); Supabase'den silinmeli (kullanıcıya hatırlat).
2. İlan verme formunu 4 adımlı akışa bölmek (tasarım tuvalinde var: büyük tür kartları, cins çipleri, tek/sürü seçimi, ilerleme çubuğu, altta "Devam").
3. İsim kararı → (kullanıcı isterse) logo → ikon/manifest/başlık güncellemesi.
4. Gerçek SMS sağlayıcı (şu an sadece test numarası).
5. KVKK aydınlatma metni ve kullanım şartları (yer tutucu); mağaza metinleri, gizlilik politikası.
6. Avukat görüşü: canlı hayvanın online satışı, Canlı Hayvan Ticareti Satıcıları yönetmeliği.
7. Push bildirim (FCM), harita/yakınlık sıralaması, video dönüştürme (iPhone .mov uyumu).
8. Moderasyon (yönetici panelinde şikâyet listesi + ilan gizle/aç, kullanıcı engelle), ilk ilanlar için tohum içerik stratejisi, kapora/ödeme koruması fikri.
9. Depo herkese açık (kullanıcı özel istedi, ama Pages özel depoda ücretli). Apple/Google geliştirici hesapları. iPhone gerçek cihaz testi.
10. İsteğe bağlı: hig-doctor-audit ile Flutter kod taraması (`npx -y hig-doctor@2.0.3 . --json`); analizdeki deprecated uyarıları (value→initialValue, activeColor→activeThumbColor, anonKey→publishableKey).
