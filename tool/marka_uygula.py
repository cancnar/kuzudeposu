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
open('web/index.html', 'w', encoding='utf-8').write(h)
print('marka uygulandi')
