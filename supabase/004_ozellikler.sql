-- Kuzu Deposu: pazar araştırmasından çıkan özellikler (003'ten sonra çalıştır). Tekrar çalıştırılabilir.
-- İlana: amaç (kurbanlık/besilik...), belgeler (küpe, sağlık raporu...), pazarlık payı, teslimat şekli, görüntülenme.
-- Yeni: fiyat karşılaştırma, görüntülenme sayacı, ilan istatistiği, güncellenen arama fonksiyonu.

-- 1) Eski arama fonksiyonu(ları)nı kaldır (imza değişiyor)
do $$
declare r record;
begin
  for r in select p.oid::regprocedure as f from pg_proc p where p.proname = 'search_listings' and p.pronamespace = 'public'::regnamespace loop
    execute 'drop function ' || r.f;
  end loop;
end $$;

-- 2) Yeni sütunlar
alter table public.listings add column if not exists amac text;
alter table public.listings add column if not exists belgeler text[] not null default '{}';
alter table public.listings add column if not exists pazarlik boolean not null default false;
alter table public.listings add column if not exists teslimat text not null default 'yerinde';
alter table public.listings add column if not exists goruntulenme integer not null default 0;

alter table public.listings drop constraint if exists listings_amac_gecerli;
alter table public.listings add constraint listings_amac_gecerli
  check (amac is null or amac in ('kurbanlik','besi','damizlik','sut_yumurta','kesim','diger'));
alter table public.listings drop constraint if exists listings_teslimat_gecerli;
alter table public.listings add constraint listings_teslimat_gecerli
  check (teslimat in ('yerinde','nakliye','ikisi'));
alter table public.listings drop constraint if exists listings_belgeler_gecerli;
alter table public.listings add constraint listings_belgeler_gecerli
  check (belgeler <@ array['kupe','saglik_raporu','pasaport','nakil','asi']::text[]);

create index if not exists listings_amac on public.listings (amac) where durum = 'aktif';

-- 3) Arama fonksiyonu (amaç + belge filtreleriyle)
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
  p_belgeler text[] default null
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
      and (p_cins is null or l.cins ilike '%' || p_cins || '%')
      and (p_sale is null or (p_sale = 'suru') = (l.adet > 1))
      and (p_adet_min is null or l.adet >= p_adet_min)
      and (p_adet_max is null or l.adet <= p_adet_max)
      and (p_yas_max is null or l.yas_min <= p_yas_max)
      and (p_yas_min is null or l.yas_max >= p_yas_min)
      and (p_kg_min is null or l.agirlik_kg >= p_kg_min)
      and (p_kg_max is null or l.agirlik_kg <= p_kg_max)
      and (p_fiyat_min is null or l.toplam_fiyat >= p_fiyat_min)
      and (p_fiyat_max is null or l.toplam_fiyat <= p_fiyat_max)
      and (p_il is null or (l.il || ' ' || l.ilce) ilike '%' || p_il || '%')
      and (p_q is null or (l.cins || ' ' || l.il || ' ' || l.ilce) ilike '%' || p_q || '%')
      and (p_min_rating is null or pr.rating_avg >= p_min_rating)
      and (p_amac is null or l.amac = p_amac)
      and (p_belgeler is null or l.belgeler @> p_belgeler)
      and not exists (select 1 from public.blocks b
                      where (b.blocker_id = auth.uid() and b.blocked_id = l.seller_id)
                         or (b.blocker_id = l.seller_id and b.blocked_id = auth.uid()))
  )
  select l, d, full_name, rating_avg, rating_count
  from base
  where p_radius_km is null or d is null or d <= p_radius_km
  order by
    case when p_sort = 'fiyat_artan'  then (l).toplam_fiyat end asc,
    case when p_sort = 'fiyat_azalan' then (l).toplam_fiyat end desc,
    case when p_sort = 'en_yakin'     then d end asc nulls last,
    (l).created_at desc
  limit least(p_limit, 50) offset greatest(p_offset, 0);
$$;

-- 4) Piyasa karşılaştırması: benzer aktif ilanların kg fiyatı
create or replace function public.fiyat_ozeti(p_tur text, p_cins text default null, p_haric uuid default null)
returns table (adet bigint, ort numeric, medyan numeric, en_dusuk numeric, en_yuksek numeric)
language sql stable as $$
  select count(*),
         round(avg(kg_fiyat), 0),
         round((percentile_cont(0.5) within group (order by kg_fiyat::double precision))::numeric, 0),
         round(min(kg_fiyat), 0),
         round(max(kg_fiyat), 0)
  from public.listings
  where durum = 'aktif' and expires_at > now() and tur = p_tur
    and (p_cins is null or cins = p_cins)
    and (p_haric is null or id <> p_haric);
$$;
grant execute on function public.fiyat_ozeti(text, text, uuid) to anon, authenticated;

-- 5) Görüntülenme sayacı (satıcının kendi bakışları sayılmaz)
create or replace function public.ilan_goruntule(p_id uuid) returns void
language sql security definer set search_path = public as $$
  update public.listings set goruntulenme = goruntulenme + 1
  where id = p_id and durum = 'aktif' and (auth.uid() is null or seller_id <> auth.uid());
$$;
grant execute on function public.ilan_goruntule(uuid) to anon, authenticated;

-- 6) İlan sahibine istatistik (başkası çağırırsa boş döner)
create or replace function public.ilan_istatistik(p_id uuid)
returns table (goruntulenme integer, favori bigint, konusma bigint)
language sql stable security definer set search_path = public as $$
  select l.goruntulenme,
         (select count(*) from public.favorites f where f.listing_id = l.id),
         (select count(*) from public.conversations c where c.listing_id = l.id)
  from public.listings l where l.id = p_id and l.seller_id = auth.uid();
$$;
grant execute on function public.ilan_istatistik(uuid) to authenticated;
