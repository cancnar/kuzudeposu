-- 012: Eş anlamlı arama cinse göre daraltıldı (13 Kasım 2026, üçüncü kullanıcı testi). 011'den sonra çalıştır; tekrar çalıştırılabilir.
-- "tavuk" artık hindi/kaz getirmez, "manda" sadece mandaları, "inek/dana/düve" manda dışı sığırları getirir.
-- Genel kelimeler (küçükbaş, büyükbaş, sığır, kanatlı, kümes, at) türün tamamını getirmeye devam eder.

create or replace function public.kelime_eslesir(l public.listings, w text) returns boolean
language sql immutable parallel safe as $$
  select
    -- Metinde kelime başından eşleşme (cins, il, ilçe, açıklama)
    (' ' || regexp_replace(public.tr_norm(l.cins || ' ' || l.il || ' ' || l.ilce || ' ' || coalesce(l.aciklama, '')), '[^a-z0-9]+', ' ', 'g'))
      like '% ' || w || '%'
    -- Küçükbaş: koyun / keçi ayrımı cinsten
    or (l.tur = 'kucukbas' and public.es_anlam(w, array['kucukbas']))
    or (l.tur = 'kucukbas' and public.tr_norm(l.cins) not like '%keci%' and public.es_anlam(w, array['koyun','kuzu','koc','toklu','sisek','marya']))
    or (l.tur = 'kucukbas' and public.tr_norm(l.cins) like '%keci%' and public.es_anlam(w, array['keci','oglak','teke','cebic']))
    -- Büyükbaş: sığır / manda ayrımı cinsten
    or (l.tur = 'buyukbas' and public.es_anlam(w, array['buyukbas','sigir']))
    or (l.tur = 'buyukbas' and public.tr_norm(l.cins) not like '%manda%' and public.es_anlam(w, array['inek','dana','duve','tosun','boga','buzagi','okuz']))
    or (l.tur = 'buyukbas' and public.tr_norm(l.cins) like '%manda%' and public.es_anlam(w, array['manda','malak']))
    -- Kanatlı: türün adı cinste yazılı (Tavuk, Hindi, Kaz, Ördek)
    or (l.tur = 'kanatli' and public.es_anlam(w, array['kanatli','kumes']))
    or (l.tur = 'kanatli' and public.tr_norm(l.cins) ~ '(tavuk|horoz|pilic|civciv|yumurtaci)' and public.es_anlam(w, array['tavuk','horoz','civciv','pilic','yumurtaci']))
    or (l.tur = 'kanatli' and public.tr_norm(l.cins) like '%hindi%' and public.es_anlam(w, array['hindi']))
    or (l.tur = 'kanatli' and public.tr_norm(l.cins) like '%kaz%' and public.es_anlam(w, array['kaz']))
    or (l.tur = 'kanatli' and public.tr_norm(l.cins) like '%ordek%' and public.es_anlam(w, array['ordek']))
    -- At: midilli cinsten, diğerleri tüm atlar
    or (l.tur = 'at' and (w in ('at', 'atlar', 'ati') or public.es_anlam(w, array['kisrak','aygir','tay'])))
    or (l.tur = 'at' and public.tr_norm(l.cins) like '%midilli%' and public.es_anlam(w, array['midilli']));
$$;
