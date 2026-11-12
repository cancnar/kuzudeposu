import json, csv, sys
bunick = json.load(open(sys.argv[1], encoding='utf-8'))
csvk = {}
resmi = json.load(open(sys.argv[3], encoding='utf-8-sig'))['data']
def kat(s):
    s = s.replace('İ','i').replace('I','ı').lower()
    for a, b in zip('çğıöşüâîû', 'cgiosuaiu'): s = s.replace(a, b)
    return ''.join(ch for ch in s if ch.isalnum())
for r in csv.DictReader(open(sys.argv[2], encoding='utf-8-sig')):
    csvk[(kat(r['city']), kat(r['district']))] = (float(r['latitude']), float(r['longitude']))
bn = {kat(i['name']): i for i in bunick}
bnt = {(kat(i['name']), kat(t['name'])): t for i in bunick for t in i['towns']}
def baslik(s):
    s = s.replace('İ','i').replace('I','ı').lower()
    out = []
    for w in s.split(' '):
        if not w: continue
        f = w[0]; f = 'İ' if f == 'i' else ('I' if f == 'ı' else f.upper())
        out.append(f + w[1:])
    return ' '.join(out)
iller = []
eksik = []
for i in sorted(resmi, key=lambda x: int(x['plaka_kodu'])):
    ad = i['il_adi'].strip()
    k = kat(ad)
    b = bn.get(k) or next((v for kk, v in bn.items() if kk.startswith(k[:5])), None)
    if not b: eksik.append(ad); continue
    ilceler = []
    for t in i['ilceler']:
        tk = kat(t['ilce_adi'])
        bt = bnt.get((kat(b['name']), tk))
        trl = lambda x: x.replace('İ','i').replace('I','ı').lower().replace('â','a')
        ilce_ad = bt['name'] if bt and trl(bt['name']) == trl(t['ilce_adi']) else baslik(t['ilce_adi'])
        koor = csvk.get((kat(b['name']), tk)) or csvk.get((k, tk)) or ((bt['latitude'], bt['longitude']) if bt else None)
        if koor is None: eksik.append(f'{ad}/{ilce_ad}'); koor = (b['latitude'], b['longitude'])
        ilceler.append((ilce_ad, round(koor[0], 4), round(koor[1], 4)))
    ilceler.sort(key=lambda x: kat(x[0]))
    iller.append((int(i['plaka_kodu']), ad, round(b['latitude'], 4), round(b['longitude'], 4), ilceler))
print('// Türkiye il ve ilçeleri (81 il, 973 ilçe) + yaklaşık merkez koordinatları.', file=sys.stderr)
print('eksik', eksik, file=sys.stderr)
L = ['// Türkiye il ve ilçeleri: 81 il, ' + str(sum(len(x[4]) for x in iller)) + ' ilçe ve yaklaşık merkez koordinatları.',
     '// Kaynak: il/ilçe adları ADNKS 2022 (github.com/snrylmz/il-ilce-json); koordinatlar github.com/emircihangir/turkey-city-coordinates',
     '// ve github.com/BuNickTamYirmiHarfli/turkey-cities-districts-json (karşılaştırıldı). tool/iller_uret.py ile üretildi; elle düzenleme.',
     '// ignore_for_file: lines_longer_than_80_chars',
     '',
     'class Ilce {', '  const Ilce(this.ad, this.lat, this.lng);', '  final String ad;', '  final double lat, lng;', '}', '',
     'class Il {', '  const Il(this.plaka, this.ad, this.lat, this.lng, this.ilceler);', '  final int plaka;', '  final String ad;', '  final double lat, lng;', '  final List<Ilce> ilceler;', '}', '',
     'const iller = <Il>[']
for p, ad, la, lo, ic in iller:
    s = ', '.join(f"Ilce('{a}', {x}, {y})" for a, x, y in ic)
    L.append(f"  Il({p}, '{ad}', {la}, {lo}, [{s}]),")
L.append('];')
open(sys.argv[4], 'w', encoding='utf-8').write('\n'.join(L) + '\n')
