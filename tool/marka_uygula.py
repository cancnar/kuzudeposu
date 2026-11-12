"""flutter create sonrası: marka ikonları, manifest ve index.html düzeltmeleri."""
import re, shutil, os
os.makedirs('web/icons', exist_ok=True)
for f in os.listdir('brand/web/icons'):
    shutil.copy(os.path.join('brand/web/icons', f), os.path.join('web/icons', f))
shutil.copy('brand/web/favicon.png', 'web/favicon.png')
shutil.copy('brand/web/manifest.json', 'web/manifest.json')
h = open('web/index.html', encoding='utf-8').read()
h = re.sub(r'<title>.*?</title>', '<title>Kuzu Deposu</title>', h, flags=re.S)
h = re.sub(r'<meta name="description"[^>]*>', '<meta name="description" content="Hayvanını güvenle al, güvenle sat.">', h)
h = re.sub(r'(<meta name="apple-mobile-web-app-title" content=")[^"]*(")', r'\1Kuzu Deposu\2', h)
h = re.sub(r'<link rel="apple-touch-icon"[^>]*>', '<link rel="apple-touch-icon" href="icons/apple-touch-icon.png">', h)
h = re.sub(r'<link rel="icon"[^>]*>', '<link rel="icon" type="image/png" href="favicon.png">', h)
extra = '<meta name="theme-color" content="#2F5D3A">\n  <meta name="apple-mobile-web-app-status-bar-style" content="default">\n  <style>html,body{background:#FBF6E9;margin:0}</style>\n'
if 'name="theme-color"' not in h:
    h = h.replace('</head>', '  ' + extra + '</head>', 1)
# Paylaşılan bağlantı önizlemesi (WhatsApp vb.)
og = ('<meta property="og:title" content="Kuzu Deposu">\n  <meta property="og:description" content="Hayvanını güvenle al, güvenle sat. Küpe ve belge bilgisi, satıcı puanı, alıcı talepleri.">\n'
      '  <meta property="og:image" content="icons/Icon-512.png">\n  <meta property="og:type" content="website">\n')
if 'property="og:title"' not in h:
    h = h.replace('</head>', '  ' + og + '</head>', 1)
# İlk açılışta (Flutter motoru inerken) boş ekran yerine logo ve "Yükleniyor"; ilk karede kaldırılır.
splash = """<div id="acilis" style="position:fixed;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center;background:#FBF6E9;font-family:-apple-system,system-ui,sans-serif;color:#6A5E48;z-index:9999;transition:opacity .2s ease-out">
    <img src="icons/Icon-192.png" alt="" width="84" height="84" style="border-radius:22px">
    <div style="margin-top:16px;font-size:20px;font-weight:700;color:#3A3220">Kuzu Deposu</div>
    <div style="margin-top:6px;font-size:14px">Yükleniyor…</div>
  </div>
  <script>window.addEventListener('flutter-first-frame',function(){var e=document.getElementById('acilis');if(e){e.style.opacity='0';setTimeout(function(){e.remove()},220)}});</script>
"""
if 'id="acilis"' not in h:
    h = re.sub(r'(<body[^>]*>)', lambda m: m.group(1) + '\n  ' + splash, h, count=1)
open('web/index.html', 'w', encoding='utf-8').write(h)
print('marka uygulandi')
