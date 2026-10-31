// CI'da uygulamanın ekran görüntülerini alır (Flutter semantics ile metne göre tıklar).
const { chromium } = require('playwright');
const fs = require('fs');
const out = process.argv[2] || 'shots';
fs.mkdirSync(out, { recursive: true });
let n = 0;
const log = [];
async function snap(p, ad) {
  n++;
  await p.screenshot({ path: `${out}/${String(n).padStart(2, '0')}_${ad}.png` });
}
async function tikla(p, metin, ms = 2000) {
  try {
    await p.getByText(metin, { exact: false }).first().click({ timeout: 5000, force: true });
    await p.waitForTimeout(ms);
    return true;
  } catch (e) {
    log.push('TIKLANAMADI ' + metin);
    return false;
  }
}
async function yaz(p, etiket, deger) {
  try {
    const el = p.getByLabel(etiket, { exact: false }).first();
    await el.click({ timeout: 5000, force: true });
    await p.keyboard.type(deger, { delay: 30 });
    await p.waitForTimeout(500);
    return true;
  } catch (e) {
    log.push('YAZILAMADI ' + etiket);
    return false;
  }
}
const alt = { ana: [78, 405], fav: [117, 405], artı: [195, 406], mesaj: [273, 405], profil: [351, 405] };
async function sekme(p, ad, ms = 2500) {
  await p.mouse.click(alt[ad][0], 844 - 40);
  await p.waitForTimeout(ms);
}
async function kaydir(p, dy, ms = 900) {
  await p.mouse.move(195, 500);
  await p.mouse.wheel(0, dy);
  await p.waitForTimeout(ms);
}
async function geri(p) {
  await p.keyboard.press('Escape').catch(() => {});
  await p.goBack().catch(() => {});
  await p.waitForTimeout(1500);
}
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2 });
  p.on('pageerror', e => log.push('PAGEERROR ' + e.message.slice(0, 200)));
  await p.goto('http://localhost:8080/kuzudeposu/', { timeout: 60000 });
  await p.waitForTimeout(9000);
  await p.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click()).catch(() => {});
  await p.waitForTimeout(1500);
  await snap(p, 'karsilama');

  // --- Misafir gezinti ---
  await tikla(p, 'Giriş yapmadan', 6000);
  await snap(p, 'ana_ilanlar');
  await tikla(p, 'Alıcı talepleri', 3000);
  await snap(p, 'ana_talepler');
  await tikla(p, 'İlanlar', 2500);
  // ilk ilan kartına gir
  await p.mouse.click(195, 380);
  await p.waitForTimeout(4000);
  await snap(p, 'detay_ust');
  for (let k = 1; k <= 4; k++) { await kaydir(p, 600); await snap(p, 'detay_' + k); }
  await geri(p);
  await snap(p, 'geri_sonrasi');
  await tikla(p, 'Filtre', 2500);
  await snap(p, 'filtre');
  await kaydir(p, 800);
  await snap(p, 'filtre_alt');
  await tikla(p, 'Temizle', 500);
  await tikla(p, 'ilanı göster', 2500);
  await sekme(p, 'fav'); await snap(p, 'favoriler_misafir');
  await sekme(p, 'mesaj'); await snap(p, 'mesajlar_misafir');
  await sekme(p, 'profil'); await snap(p, 'profil_misafir');

  // --- Giriş (test numarası) ---
  await tikla(p, 'numaram ile giriş', 2500);
  await snap(p, 'telefon');
  await yaz(p, 'Cep telefonu', '5559999999');
  await tikla(p, 'okudum', 800);
  await snap(p, 'telefon_dolu');
  await tikla(p, 'Kodu gönder', 4000);
  await snap(p, 'otp');
  await p.keyboard.type('123456', { delay: 60 });
  await p.waitForTimeout(500);
  await tikla(p, 'Doğrula', 5000);
  await snap(p, 'profil_kurulum');
  const urlSonrasi = await p.evaluate(() => document.body.innerText.slice(0, 200)).catch(() => '');
  await yaz(p, 'Ad soyad', 'CI Test Kullanıcı');
  await yaz(p, 'İl', 'Manisa');
  await yaz(p, 'İlçe', 'Salihli');
  await tikla(p, 'Yetiştirici', 500);
  await snap(p, 'profil_kurulum_dolu');
  await tikla(p, 'Devam', 5000) || await tikla(p, 'Kaydet', 5000) || await tikla(p, 'Başla', 5000);
  await snap(p, 'giris_sonrasi_ana');

  // --- Girişli ekranlar ---
  await p.mouse.click(195, 804); await p.waitForTimeout(1500);
  await snap(p, 'artı_menü');
  await tikla(p, 'Hayvan satıyorum', 3000);
  await snap(p, 'ilan_ver_1');
  for (let k = 2; k <= 5; k++) { await kaydir(p, 650); await snap(p, 'ilan_ver_' + k); }
  await geri(p);
  await p.mouse.click(195, 804); await p.waitForTimeout(1500);
  await tikla(p, 'Hayvan arıyorum', 3000);
  await snap(p, 'talep_ver_1');
  await kaydir(p, 650); await snap(p, 'talep_ver_2');
  await geri(p);
  await sekme(p, 'fav'); await snap(p, 'favoriler');
  await sekme(p, 'mesaj'); await snap(p, 'mesajlar');
  await sekme(p, 'profil'); await snap(p, 'profil');
  await kaydir(p, 500); await snap(p, 'profil_alt');
  await tikla(p, 'İlanlarım', 2500); await snap(p, 'ilanlarim'); await geri(p);
  await tikla(p, 'Ayarlar', 2500); await snap(p, 'ayarlar'); await geri(p);
  await tikla(p, 'Kayıtlı aramalarım', 2500); await snap(p, 'kayitli_aramalar'); await geri(p);
  log.push('SON ' + urlSonrasi.replace(/\n/g, ' '));
  fs.writeFileSync(`${out}/log.txt`, log.join('\n'));
  await b.close();
})().catch(e => { fs.writeFileSync(`${out}/log.txt`, 'HATA ' + e.message + '\n' + log.join('\n')); process.exit(0); });
