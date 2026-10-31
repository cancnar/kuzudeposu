// CI'da uygulamanın ekran görüntülerini alır (Flutter semantics ile metne göre tıklar).
const { chromium } = require('playwright');
const fs = require('fs');
const out = process.argv[2] || 'shots';
fs.mkdirSync(out, { recursive: true });
let n = 0;
const log = [];
async function snap(p, ad) {
  n++;
  const f = `${out}/${String(n).padStart(2, '0')}_${ad}.png`;
  await p.screenshot({ path: f });
  log.push('foto ' + f);
}
async function tikla(p, metin, ms = 2500) {
  try {
    await p.getByText(metin, { exact: false }).first().click({ timeout: 6000, force: true });
    await p.waitForTimeout(ms);
    return true;
  } catch (e) {
    log.push('TIKLANAMADI ' + metin);
    return false;
  }
}
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2 });
  p.on('pageerror', e => log.push('PAGEERROR ' + e.message.slice(0, 200)));
  await p.goto('http://localhost:8080/kuzudeposu/', { timeout: 60000 });
  await p.waitForTimeout(9000);
  // erişilebilirlik ağacını aç
  await p.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click()).catch(() => {});
  await p.waitForTimeout(1500);
  await snap(p, 'karsilama');
  const metinler = await p.evaluate(() => [...document.querySelectorAll('flt-semantics')].map(e => (e.getAttribute('aria-label') || e.textContent || '').trim()).filter(Boolean).slice(0, 40));
  log.push('SEMANTICS ' + JSON.stringify(metinler));
  if (await tikla(p, 'Giriş yapmadan', 6000)) {
    await snap(p, 'ana_ilanlar');
    await p.mouse.move(195, 600);
    await p.mouse.wheel(0, 700); await p.waitForTimeout(1200);
    await snap(p, 'ana_ilanlar_kaydir');
    await p.mouse.wheel(0, -2000); await p.waitForTimeout(800);
    await tikla(p, 'Alıcı talepleri', 3000);
    await snap(p, 'ana_talepler');
    await tikla(p, 'İlanlar', 2500);
    await tikla(p, 'Filtre', 2500);
    await snap(p, 'filtre');
    await p.mouse.wheel(0, 900); await p.waitForTimeout(1000);
    await snap(p, 'filtre_alt');
    await tikla(p, 'ilanı göster', 3000);
    await p.waitForTimeout(1500);
    // ilk ilana gir
    await tikla(p, '₺', 3500);
    await snap(p, 'detay_ust');
    await p.mouse.move(195, 600);
    for (let k = 1; k <= 3; k++) { await p.mouse.wheel(0, 650); await p.waitForTimeout(1000); await snap(p, 'detay_' + k); }
    await p.goBack().catch(() => {});
    await p.waitForTimeout(1500);
    await tikla(p, 'Favoriler', 2500);
    await snap(p, 'favoriler_misafir');
    await tikla(p, 'Profil', 2500);
    await snap(p, 'profil_misafir');
    await tikla(p, 'İlan ver', 2500);
    await snap(p, 'artı_menü');
  }
  fs.writeFileSync(`${out}/log.txt`, log.join('\n'));
  await b.close();
})().catch(e => { fs.writeFileSync(`${out}/log.txt`, 'HATA ' + e.message + '\n' + log.join('\n')); process.exit(0); });
