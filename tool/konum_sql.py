# lib/iller.dart -> 010 SQL'inin sonundaki ilce_konum verisi
import re, sys
src = open(sys.argv[1], encoding='utf-8').read()
rows = []
for m in re.finditer(r"Il\((\d+), '([^']+)', ([\d.]+), ([\d.]+), \[(.*?)\]\),", src):
    _, il, ila, ilo, body = m.groups()
    for t in re.finditer(r"Ilce\('([^']+)', ([\d.]+), ([\d.]+)\)", body):
        rows.append(f"('{il}','{t.group(1)}',{t.group(2)},{t.group(3)},{ila},{ilo})")
out = ["insert into public.ilce_konum (il, ilce, lat, lng, il_lat, il_lng) values"]
out.append(',\n'.join(rows))
out.append("on conflict (il, ilce) do update set lat = excluded.lat, lng = excluded.lng, il_lat = excluded.il_lat, il_lng = excluded.il_lng;")
out.append("""
-- Mevcut kayıtları düzelt: il/ilçe resmi yazılışa, ilanlara konum (güvenilir işlem: makul değer denetimi uygulanmaz)
do $$ begin
  perform set_config('kuzu.guvenilir', '1', true);
  update public.listings set il = il;
  update public.profiles set il = il;
  update public.wanted_ads set il = il;
  perform set_config('kuzu.guvenilir', '', true);
end $$;""")
print('\n'.join(out))
print(len(rows), file=sys.stderr)
