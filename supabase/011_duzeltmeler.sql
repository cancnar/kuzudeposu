-- 011: Kullanıcı testi (13 Kasım 2026) düzeltmeleri. 010'dan sonra çalıştır; tekrar çalıştırılabilir.
-- 1) Arama: kelime başından eşleşme ("inek" artık "binek"i bulmaz) + hayvan adı eş anlamlıları
--    (koyun/kuzu → küçükbaş koyun, keçi/oğlak → küçükbaş keçi, inek/dana/düve/tosun → büyükbaş, …).
-- 2) İl + mesafe: "Manisa · 100 km" il merkezinden 100 km'yi VE Manisa'nın tüm ilçelerini kapsar
--    (yeni parametre p_il_veya; eski uygulama sürümleri parametresiz çağırmaya devam edebilir).
-- 3) Satıcı değerlendirmesi: alıcı mesaj yazmış VE satıcı en az bir kez yanıt vermiş olmalı.
-- 4) Ön onay açıkken onaylanmış ilanın açıklaması değişirse ilan yeniden onaya düşer.

-- ============ 1) ARAMA YARDIMCILARI ============
-- w, listedeki bir kelimeyle başlıyor mu ("kuzular") ya da (en az 3 harfse) bir kelimenin başı mı ("kuz")?
create or replace function public.es_anlam(w text, kelimeler text[]) returns boolean
language sql immutable parallel safe as $$
  select exists (select 1 from unnest(kelimeler) k
                 where w like k || '%' or (length(w) >= 3 and k like w || '%'));
$$;

-- Tek bir arama kelimesi (tr_norm'lanmış) ilanla eşleşir mi? Metinde kelime başından ya da eş anlamlıyla.
create or replace function public.kelime_eslesir(l public.listings, w text) returns boolean
language sql immutable parallel safe as $$
  select
    (' ' || regexp_replace(public.tr_norm(l.cins || ' ' || l.il || ' ' || l.ilce || ' ' || coalesce(l.aciklama, '')), '[^a-z0-9]+', ' ', 'g'))
      like '% ' || w || '%'
    or (l.tur = 'kucukbas' and public.tr_norm(l.cins) not like '%keci%' and public.es_anlam(w, array['koyun','kuzu','koc','toklu','sisek','marya']))
    or (l.tur = 'kucukbas' and public.tr_norm(l.cins) like '%keci%' and public.es_anlam(w, array['keci','oglak','teke','cebic']))
    or (l.tur = 'kucukbas' and public.es_anlam(w, array['kucukbas']))
    or (l.tur = 'buyukbas' and public.es_anlam(w, array['buyukbas','inek','dana','duve','tosun','boga','sigir','manda','buzagi','malak','okuz']))
    or (l.tur = 'kanatli' and public.es_anlam(w, array['kanatli','tavuk','horoz','civciv','hindi','kaz','ordek','bildircin','pilic']))
    or (l.tur = 'at' and (w in ('at', 'atlar', 'ati') or public.es_anlam(w, array['kisrak','aygir','tay','midilli','katir','esek'])));
$$;

-- Aramadaki her kelime eşleşmeli ("kıvırcık salihli" → ikisi de).
create or replace function public.ilan_aramaya_uyar(l public.listings, q text) returns boolean
language sql immutable parallel safe as $$
  select coalesce(bool_and(public.kelime_eslesir(l, w)), true)
  from unnest(string_to_array(trim(regexp_replace(public.tr_norm(q), '[^a-z0-9]+', ' ', 'g')), ' ')) w
  where w <> '';
$$;

-- ============ 2) ARAMA FONKSİYONU (p_il_veya eklendi) ============
drop function if exists public.search_listings(text, text, text, text, int, int, int, int, numeric, numeric, numeric, numeric, text,
  double precision, double precision, double precision, numeric, text, int, int, text, text[]);
create or replace function public.search_listings(
  p_q text default null, p_tur text default null, p_cins text default null,
  p_sale text default null,
  p_adet_min int default null, p_adet_max int default null,
  p_yas_min int default null,  p_yas_max int default null,
  p_kg_min numeric default null, p_kg_max numeric default null,
  p_fiyat_min numeric default null, p_fiyat_max numeric default null,
  p_il text default null,
  p_lat double precision default null, p_lng double precision default null, p_radius_km double precision default null,
  p_min_rating numeric default null,
  p_sort text default 'en_yeni',
  p_limit int default 20, p_offset int default 0,
  p_amac text default null,
  p_belgeler text[] default null,
  p_il_veya text default null   -- yarıçapın dışında kalsa da bu ildeki ilanlar dahil edilir
) returns table (listing public.listings, distance_km double precision, seller_name text, seller_rating numeric, seller_rating_count int)
language sql stable as $$
  with base as (
    select l,
      case when p_lat is not null and p_lng is not null and l.lat is not null and l.lng is not null then
        2 * 6371 * asin(sqrt(
          power(sin(radians(l.lat - p_lat) / 2), 2) +
          cos(radians(p_lat)) * cos(radians(l.lat)) * power(sin(radians(l.lng - p_lng) / 2), 2)))
      end as d,
      pr.full_name, pr.rating_avg, pr.rating_count
    from public.listings l
    join public.profiles pr on pr.id = l.seller_id
    where l.durum = 'aktif' and l.expires_at > now()
      and (p_tur is null or l.tur = p_tur)
      and (p_cins is null or public.tr_norm(l.cins) like '%' || public.tr_norm(p_cins) || '%')
      and (p_sale is null or (p_sale = 'suru') = (l.adet > 1))
      and (p_adet_min is null or l.adet >= p_adet_min)
      and (p_adet_max is null or l.adet <= p_adet_max)
      and (p_yas_max is null or l.yas_min <= p_yas_max)
      and (p_yas_min is null or l.yas_max >= p_yas_min)
      and (p_kg_min is null or l.agirlik_kg >= p_kg_min)
      and (p_kg_max is null or l.agirlik_kg <= p_kg_max)
      and (p_fiyat_min is null or l.toplam_fiyat >= p_fiyat_min)
      and (p_fiyat_max is null or l.toplam_fiyat <= p_fiyat_max)
      and (p_il is null or public.tr_norm(l.il || ' ' || l.ilce) like '%' || public.tr_norm(p_il) || '%')
      and (p_q is null or public.ilan_aramaya_uyar(l, p_q))
      and (p_min_rating is null or pr.rating_avg >= p_min_rating)
      and (p_amac is null or l.amac = p_amac)
      and (p_belgeler is null or l.belgeler @> p_belgeler)
      and not exists (select 1 from public.blocks b
                      where (b.blocker_id = auth.uid() and b.blocked_id = l.seller_id)
                         or (b.blocker_id = l.seller_id and b.blocked_id = auth.uid()))
  )
  select l, d, full_name, rating_avg, rating_count
  from base
  where p_radius_km is null
     or (d is not null and d <= p_radius_km)
     or (p_il_veya is not null and public.tr_norm((l).il) = public.tr_norm(p_il_veya))
  order by
    case when p_sort = 'fiyat_artan'  then (l).toplam_fiyat end asc,
    case when p_sort = 'fiyat_azalan' then (l).toplam_fiyat end desc,
    case when p_sort = 'en_yakin'     then d end asc nulls last,
    (l).created_at desc
  limit least(p_limit, 50) offset greatest(p_offset, 0);
$$;
grant execute on function public.search_listings(text, text, text, text, int, int, int, int, numeric, numeric, numeric, numeric, text,
  double precision, double precision, double precision, numeric, text, int, int, text, text[], text) to anon, authenticated;

-- ============ 3) DEĞERLENDİRME ŞARTI ============
drop policy if exists reviews_insert on public.reviews;
create policy reviews_insert on public.reviews for insert to authenticated with check (
  reviewer_id = auth.uid()
  and exists (select 1 from public.conversations c
              where c.id = conversation_id and c.buyer_id = auth.uid() and c.seller_id = reviews.seller_id)
  and exists (select 1 from public.messages m where m.conversation_id = reviews.conversation_id and m.sender_id = auth.uid())
  and exists (select 1 from public.messages m where m.conversation_id = reviews.conversation_id and m.sender_id = reviews.seller_id));

-- ============ 4) DÜZENLENEN İLAN YENİDEN ONAYA ============
create or replace function public.ilan_guncelle_kontrol() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if public.guvenilir() then return new; end if;
  new.moderasyon := old.moderasyon; new.moderasyon_neden := old.moderasyon_neden; new.moderasyon_at := old.moderasyon_at;
  if new.durum is distinct from old.durum and new.durum in ('aktif', 'satildi') then
    if old.moderasyon is not null then
      raise exception 'Bu ilan yönetici incelemesinde; yeniden yayınlanamaz.' using errcode = '42501';
    end if;
    if new.durum = 'aktif' and public.askida_mi(new.seller_id) then
      raise exception 'Hesabın askıya alındı; ilan yayınlanamaz.' using errcode = '42501';
    end if;
  end if;
  -- Ön onay açıkken yayındaki ilanın açıklaması değişirse yönetici yeniden bakar.
  if public.ayar_acik('on_onay') and old.moderasyon is null and old.durum = 'aktif'
     and new.aciklama is distinct from old.aciklama then
    new.durum := 'pasif';
    new.moderasyon := 'onay_bekliyor';
    new.moderasyon_at := now();
  end if;
  return new;
end $$;
