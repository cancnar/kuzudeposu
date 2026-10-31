-- Kuzu Deposu: Supabase (PostgreSQL) veri tabanı şeması, sürüm 0.1
-- Not: Bu dosya henüz gerçek bir veri tabanında çalıştırılıp test EDİLMEDİ.
-- Supabase > SQL Editor'e yapıştırıp çalıştır, hata çıkarsa hata mesajını bana gönder.
-- Telefon numarası profiles tablosunda TUTULMAZ; sadece auth.users içinde durur (gizlilik).

-- ============ PROFİLLER ============
create table public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  full_name     text not null check (char_length(full_name) between 3 and 80),
  il            text not null,
  ilce          text not null,
  role          text not null default 'yetistirici' check (role in ('yetistirici','tuccar','alici')),
  avatar_path   text,
  show_phone    boolean not null default false,
  rating_avg    numeric(3,2) not null default 0,
  rating_count  integer not null default 0,
  created_at    timestamptz not null default now()
);

-- ============ İLANLAR ============
create table public.listings (
  id            uuid primary key default gen_random_uuid(),
  seller_id     uuid not null references public.profiles(id) on delete cascade,
  tur           text not null check (tur in ('buyukbas','kucukbas','kanatli','at')),
  cins          text not null,
  cinsiyet      text not null check (cinsiyet in ('disi','erkek','karisik')),
  adet          integer not null default 1 check (adet between 1 and 5000),
  yas_min       integer not null check (yas_min >= 0),
  yas_max       integer not null,
  agirlik_kg    numeric(8,2) not null check (agirlik_kg > 0),   -- tek hayvanda canlı ağırlık, sürüde ORTALAMA
  toplam_fiyat  numeric(14,2) not null check (toplam_fiyat > 0),
  kg_fiyat      numeric(12,2) generated always as (toplam_fiyat / (adet * agirlik_kg)) stored,
  satis_sekli   text not null default 'birlikte' check (satis_sekli in ('birlikte','adet_adet')),
  aciklama      text check (char_length(aciklama) <= 2000),
  il            text not null,
  ilce          text not null,
  lat           double precision,
  lng           double precision,
  durum         text not null default 'aktif' check (durum in ('aktif','satildi','pasif','kaldirildi')),
  created_at    timestamptz not null default now(),
  expires_at    timestamptz not null default (now() + interval '60 days'),
  constraint yas_aralik check (yas_max >= yas_min),
  constraint tek_hayvan_yas check (adet > 1 or yas_max = yas_min)
);
create index listings_durum_created on public.listings (durum, created_at desc);
create index listings_filtre on public.listings (tur, il, ilce);
create index listings_seller on public.listings (seller_id);

create table public.listing_photos (
  id          uuid primary key default gen_random_uuid(),
  listing_id  uuid not null references public.listings(id) on delete cascade,
  path        text not null,           -- Storage 'listing-photos' kovasındaki yol
  sort_order  integer not null default 0
);
create index listing_photos_listing on public.listing_photos (listing_id, sort_order);

-- ============ FAVORİ, KAYITLI ARAMA ============
create table public.favorites (
  user_id     uuid not null references public.profiles(id) on delete cascade,
  listing_id  uuid not null references public.listings(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (user_id, listing_id)
);

create table public.saved_searches (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  title       text not null,
  filters     jsonb not null default '{}'::jsonb,
  notify      boolean not null default true,
  created_at  timestamptz not null default now()
);

-- ============ MESAJLAŞMA ============
create table public.conversations (
  id          uuid primary key default gen_random_uuid(),
  listing_id  uuid not null references public.listings(id) on delete cascade,
  buyer_id    uuid not null references public.profiles(id) on delete cascade,
  seller_id   uuid not null references public.profiles(id) on delete cascade,
  created_at  timestamptz not null default now(),
  unique (listing_id, buyer_id),
  check (buyer_id <> seller_id)
);

create table public.messages (
  id               uuid primary key default gen_random_uuid(),
  conversation_id  uuid not null references public.conversations(id) on delete cascade,
  sender_id        uuid not null references public.profiles(id) on delete cascade,
  body             text not null check (char_length(body) between 1 and 2000),
  created_at       timestamptz not null default now(),
  read_at          timestamptz
);
create index messages_conv on public.messages (conversation_id, created_at);

-- ============ YORUM, ŞİKAYET, ENGEL ============
create table public.reviews (
  id               uuid primary key default gen_random_uuid(),
  conversation_id  uuid not null references public.conversations(id) on delete cascade,
  reviewer_id      uuid not null references public.profiles(id) on delete cascade,
  seller_id        uuid not null references public.profiles(id) on delete cascade,
  rating           integer not null check (rating between 1 and 5),
  comment          text check (char_length(comment) <= 1000),
  created_at       timestamptz not null default now(),
  unique (conversation_id, reviewer_id)
);

create table public.reports (
  id                uuid primary key default gen_random_uuid(),
  reporter_id       uuid not null references public.profiles(id) on delete cascade,
  listing_id        uuid references public.listings(id) on delete set null,
  reported_user_id  uuid references public.profiles(id) on delete set null,
  reason            text not null check (reason in ('baska_hayvan_fotografi','sahte_ilan','kapora_istiyor','uygunsuz_mesaj','diger')),
  detail            text check (char_length(detail) <= 1000),
  status            text not null default 'yeni' check (status in ('yeni','inceleniyor','kapandi')),
  created_at        timestamptz not null default now()
);

create table public.blocks (
  blocker_id  uuid not null references public.profiles(id) on delete cascade,
  blocked_id  uuid not null references public.profiles(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

-- ============ BİLDİRİM ============
create table public.notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  type        text not null,
  title       text not null,
  body        text,
  data        jsonb not null default '{}'::jsonb,
  read_at     timestamptz,
  created_at  timestamptz not null default now()
);
create index notifications_user on public.notifications (user_id, created_at desc);

create table public.device_tokens (
  token       text primary key,
  user_id     uuid not null references public.profiles(id) on delete cascade,
  platform    text not null check (platform in ('ios','android')),
  updated_at  timestamptz not null default now()
);

-- ============ PUAN ORTALAMASI (otomatik) ============
create or replace function public.refresh_rating() returns trigger
language plpgsql security definer set search_path = public as $$
declare sid uuid := coalesce(new.seller_id, old.seller_id);
begin
  update public.profiles p set
    rating_avg   = coalesce((select round(avg(rating)::numeric, 2) from public.reviews where seller_id = sid), 0),
    rating_count = (select count(*) from public.reviews where seller_id = sid)
  where p.id = sid;
  return null;
end $$;
create trigger reviews_rating after insert or update or delete on public.reviews
  for each row execute function public.refresh_rating();

-- ============ YARDIMCI: konuşmanın tarafı mı? ============
create or replace function public.is_participant(conv uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.conversations c
                 where c.id = conv and auth.uid() in (c.buyer_id, c.seller_id));
$$;

-- ============ GÜVENLİK (RLS) ============
alter table public.profiles       enable row level security;
alter table public.listings       enable row level security;
alter table public.listing_photos enable row level security;
alter table public.favorites      enable row level security;
alter table public.saved_searches enable row level security;
alter table public.conversations  enable row level security;
alter table public.messages       enable row level security;
alter table public.reviews        enable row level security;
alter table public.reports        enable row level security;
alter table public.blocks         enable row level security;
alter table public.notifications  enable row level security;
alter table public.device_tokens  enable row level security;

-- Profiller: misafir de ilan sahibinin adını ve puanını görebilir; telefon bu tabloda yok.
create policy profiles_select on public.profiles for select using (true);
create policy profiles_insert on public.profiles for insert to authenticated with check (id = auth.uid());
create policy profiles_update on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- İlanlar: aktif ilanı herkes görür; kendi ilanını (her durumda) sadece sahibi yönetir.
create policy listings_select on public.listings for select
  using ((durum = 'aktif' and expires_at > now()) or seller_id = auth.uid());
create policy listings_insert on public.listings for insert to authenticated with check (seller_id = auth.uid());
create policy listings_update on public.listings for update to authenticated using (seller_id = auth.uid()) with check (seller_id = auth.uid());
create policy listings_delete on public.listings for delete to authenticated using (seller_id = auth.uid());

create policy photos_select on public.listing_photos for select using (
  exists (select 1 from public.listings l where l.id = listing_id));
create policy photos_write on public.listing_photos for all to authenticated
  using (exists (select 1 from public.listings l where l.id = listing_id and l.seller_id = auth.uid()))
  with check (exists (select 1 from public.listings l where l.id = listing_id and l.seller_id = auth.uid()));

create policy favorites_own on public.favorites for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy saved_own    on public.saved_searches for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy devtok_own   on public.device_tokens for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy blocks_own   on public.blocks for all to authenticated using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());

create policy notif_select on public.notifications for select to authenticated using (user_id = auth.uid());
create policy notif_update on public.notifications for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Konuşma: sadece tarafları görür; alıcı başlatır, satıcıyı engellemiş/engellenmiş olamaz, satıcı ilanın gerçek sahibi olmalı.
create policy conv_select on public.conversations for select to authenticated using (auth.uid() in (buyer_id, seller_id));
create policy conv_insert on public.conversations for insert to authenticated with check (
  buyer_id = auth.uid()
  and exists (select 1 from public.listings l where l.id = listing_id and l.seller_id = seller_id and l.durum = 'aktif')
  and not exists (select 1 from public.blocks b
                  where (b.blocker_id = seller_id and b.blocked_id = buyer_id)
                     or (b.blocker_id = buyer_id and b.blocked_id = seller_id)));

create policy msg_select on public.messages for select to authenticated using (public.is_participant(conversation_id));
create policy msg_insert on public.messages for insert to authenticated with check (
  sender_id = auth.uid() and public.is_participant(conversation_id)
  and not exists (select 1 from public.conversations c join public.blocks b
                  on (b.blocker_id = c.buyer_id and b.blocked_id = c.seller_id)
                  or (b.blocker_id = c.seller_id and b.blocked_id = c.buyer_id)
                  where c.id = conversation_id));
create policy msg_read on public.messages for update to authenticated
  using (public.is_participant(conversation_id) and sender_id <> auth.uid())
  with check (public.is_participant(conversation_id) and sender_id <> auth.uid());

-- Yorum: herkes okur; sadece o ilanda satıcıyla gerçekten konuşmuş alıcı yazar (sahte yorumu azaltır).
create policy reviews_select on public.reviews for select using (true);
create policy reviews_insert on public.reviews for insert to authenticated with check (
  reviewer_id = auth.uid()
  and exists (select 1 from public.conversations c
              where c.id = conversation_id and c.buyer_id = auth.uid() and c.seller_id = reviews.seller_id)
  and exists (select 1 from public.messages m where m.conversation_id = reviews.conversation_id and m.sender_id = auth.uid()));

create policy reports_insert on public.reports for insert to authenticated with check (reporter_id = auth.uid());
create policy reports_select on public.reports for select to authenticated using (reporter_id = auth.uid());

-- ============ ARAMA / FİLTRE FONKSİYONU ============
-- Prototipteki filtre mantığıyla aynı: yaş aralığı KESİŞİM, ağırlık sürüde ortalama.
create or replace function public.search_listings(
  p_q text default null, p_tur text default null, p_cins text default null,
  p_sale text default null,                 -- 'tek' | 'suru' | null
  p_adet_min int default null, p_adet_max int default null,
  p_yas_min int default null,  p_yas_max int default null,
  p_kg_min numeric default null, p_kg_max numeric default null,
  p_fiyat_min numeric default null, p_fiyat_max numeric default null,
  p_il text default null,
  p_lat double precision default null, p_lng double precision default null, p_radius_km double precision default null,
  p_min_rating numeric default null,
  p_sort text default 'en_yeni',            -- en_yeni | fiyat_artan | fiyat_azalan | en_yakin
  p_limit int default 20, p_offset int default 0
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

-- ============ STORAGE (SQL Editor'de değil, panelden kur) ============
-- 1) Storage > New bucket: 'listing-photos' (Public: açık, okuma herkese; dosya boyutu sınırı 5 MB, sadece image/*)
-- 2) Storage > New bucket: 'avatars' (Public)
-- 3) Yükleme kuralı: sadece giriş yapmış kullanıcı, kendi klasörüne ('<user_id>/dosya.jpg') yükleyebilsin.
