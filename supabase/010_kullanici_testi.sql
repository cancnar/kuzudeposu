-- Kuzu Deposu: KULLANICI TESTİ DÜZELTMELERİ (12 Kasım 2026). 009'dan sonra çalıştır. Tekrar çalıştırılabilir.
--  1) Türkçe harf duyarsız arama (KIVIRCIK = kıvırcık = kivircik), açıklamada da arar
--  2) İl/ilçe: resmi adlara düzeltme ("manisa" -> "Manisa") ve ilçe merkezinden otomatik konum (mesafe araması)
--  3) Makul değer denetimi (11 kg Holstein, 1.111 ₺ büyükbaş gibi ilanlar reddedilir)
--  4) Yapılandırılmış teklif: kabul / ret; mesaj gövdesini karşı taraf değiştiremez
--  5) Destek mesajları (Yardım ve destek > Bize yaz) + yönetici listesi
--  6) Örnek alıcı talepleri (cccccccc-… örnek hesaplar; sayılara dahil değil)
-- İl/ilçe koordinat tablosu (ilce_konum) dosyanın sonunda; tool/iller_uret.py --sql ile üretilir.

-- ============ 1) TÜRKÇE NORMALLEŞTİRME + ARAMA ============
create or replace function public.tr_norm(p text) returns text
language sql immutable parallel safe as $$
  select regexp_replace(
           translate(lower(translate(coalesce(p, ''), 'ÇĞİIÖŞÜÂÎÛ', 'çğiıöşüâîû')), 'çğıöşüâîû', 'cgiosuaiu'),
           '\s+', ' ', 'g');
$$;

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
      and (p_q is null or public.tr_norm(l.cins || ' ' || l.il || ' ' || l.ilce || ' ' || coalesce(l.aciklama, ''))
                          like '%' || public.tr_norm(p_q) || '%')
      and (p_min_rating is null or pr.rating_avg >= p_min_rating)
      and (p_amac is null or l.amac = p_amac)
      and (p_belgeler is null or l.belgeler @> p_belgeler)
      and not exists (select 1 from public.blocks b
                      where (b.blocker_id = auth.uid() and b.blocked_id = l.seller_id)
                         or (b.blocker_id = l.seller_id and b.blocked_id = auth.uid()))
  )
  select l, d, full_name, rating_avg, rating_count
  from base
  where p_radius_km is null or (d is not null and d <= p_radius_km)
  order by
    case when p_sort = 'fiyat_artan'  then (l).toplam_fiyat end asc,
    case when p_sort = 'fiyat_azalan' then (l).toplam_fiyat end desc,
    case when p_sort = 'en_yakin'     then d end asc nulls last,
    (l).created_at desc
  limit least(p_limit, 50) offset greatest(p_offset, 0);
$$;

-- Kayıtlı arama bildirimi de Türkçe harf duyarsız olsun (002'deki fonksiyonun yeni hali)
create or replace function public.bildirim_yeni_ilan() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.notifications (user_id, type, title, body, data)
  select s.user_id, 'yeni_ilan', 'Aramana uyan yeni ilan',
         new.cins || ' · ' || new.adet || ' baş · ' || new.ilce,
         jsonb_build_object('listing_id', new.id)
  from public.saved_searches s
  where s.notify and s.user_id <> new.seller_id
    and (coalesce(s.filters->>'tur','Hepsi') = 'Hepsi'
         or s.filters->>'tur' = case new.tur when 'buyukbas' then 'Büyükbaş' when 'kucukbas' then 'Küçükbaş' when 'kanatli' then 'Kanatlı' else 'At' end)
    and (coalesce(s.filters->>'cins','') = '' or public.tr_norm(new.cins) like '%' || public.tr_norm(s.filters->>'cins') || '%')
    and (coalesce(s.filters->>'il','') = '' or public.tr_norm(new.il || ' ' || new.ilce) like '%' || public.tr_norm(s.filters->>'il') || '%');
  return null;
end $$;

-- ============ 2) İL / İLÇE: RESMİ AD + KONUM ============
create table if not exists public.ilce_konum (
  il        text not null,
  ilce      text not null,
  lat       double precision not null,
  lng       double precision not null,
  il_lat    double precision not null,
  il_lng    double precision not null,
  il_n      text generated always as (public.tr_norm(il)) stored,
  ilce_n    text generated always as (public.tr_norm(ilce)) stored,
  primary key (il, ilce)
);
create index if not exists ilce_konum_n on public.ilce_konum (il_n, ilce_n);
alter table public.ilce_konum enable row level security;
drop policy if exists ilce_konum_oku on public.ilce_konum;
create policy ilce_konum_oku on public.ilce_konum for select using (true);
grant select on public.ilce_konum to anon, authenticated;

-- Kaydedilen il/ilçeyi resmi yazılışa çevirir ("manisa" -> "Manisa"). Bulunamazsa olduğu gibi bırakır.
create or replace function public.il_ilce_duzelt() returns trigger
language plpgsql security definer set search_path = public as $$
declare k public.ilce_konum; il_ad text;
begin
  select il into il_ad from public.ilce_konum where il_n = public.tr_norm(trim(new.il)) limit 1;
  if il_ad is not null then new.il := il_ad; end if;
  if tg_table_name in ('listings', 'profiles') then
    select * into k from public.ilce_konum where il_n = public.tr_norm(trim(new.il)) and ilce_n = public.tr_norm(trim(new.ilce)) limit 1;
    if k.il is not null then new.ilce := k.ilce; end if;
  end if;
  if tg_table_name = 'listings' then
    if tg_op = 'INSERT' or new.il is distinct from old.il or new.ilce is distinct from old.ilce or new.lat is null then
      if k.il is not null then
        new.lat := k.lat; new.lng := k.lng;
      elsif il_ad is not null then
        select il_lat, il_lng into new.lat, new.lng from public.ilce_konum where il = il_ad limit 1;
      end if;
    end if;
  end if;
  return new;
end $$;
drop trigger if exists listings_il_ilce on public.listings;
create trigger listings_il_ilce before insert or update of il, ilce, lat on public.listings
  for each row execute function public.il_ilce_duzelt();
drop trigger if exists profiles_il_ilce on public.profiles;
create trigger profiles_il_ilce before insert or update of il, ilce on public.profiles
  for each row execute function public.il_ilce_duzelt();
drop trigger if exists wanted_il on public.wanted_ads;
create trigger wanted_il before insert or update of il on public.wanted_ads
  for each row execute function public.il_ilce_duzelt();

-- ============ 3) MAKUL DEĞER DENETİMİ ============
-- Hayvan başı ağırlık ve kg fiyatı türe göre geniş aralıklarda olmalı. Fiyat sınırları enflasyonla
-- yılda bir gözden geçirilir (uygulamadaki makulAralik ile aynı tutulur: lib/models.dart).
create or replace function public.ilan_makul() returns trigger
language plpgsql security definer set search_path = public as $$
declare kg_min numeric; kg_max numeric; f_min numeric; f_max numeric; ad text; kgf numeric;
begin
  if public.guvenilir() then return new; end if;
  select x.kmin, x.kmax, x.fmin, x.fmax, x.ad into kg_min, kg_max, f_min, f_max, ad from (values
    ('buyukbas', 40, 1500, 100, 3000, 'büyükbaş'),
    ('kucukbas',  3,  200, 100, 3000, 'küçükbaş'),
    ('kanatli', 0.2,   25,  20, 5000, 'kanatlı'),
    ('at',       50, 1200,  20, 10000, 'at')) x(tur, kmin, kmax, fmin, fmax, ad)
  where x.tur = new.tur;
  if new.agirlik_kg < kg_min or new.agirlik_kg > kg_max then
    raise exception 'Ağırlık makul değil: % için hayvan başı % – % kg arası olmalı.', ad, kg_min, kg_max using errcode = '22023';
  end if;
  kgf := new.toplam_fiyat / (new.adet * new.agirlik_kg);
  if kgf < f_min or kgf > f_max then
    raise exception 'Fiyat makul değil: kg fiyatı % ₺ çıkıyor; % için % – % ₺/kg arası olmalı. Toplam fiyatı ve ağırlığı kontrol et.',
      round(kgf), ad, f_min, f_max using errcode = '22023';
  end if;
  if new.yas_max > 360 then
    raise exception 'Yaş makul değil: en fazla 360 ay (30 yıl) girilebilir.' using errcode = '22023';
  end if;
  return new;
end $$;
drop trigger if exists listings_makul on public.listings;
create trigger listings_makul before insert or update of tur, adet, agirlik_kg, toplam_fiyat, yas_min, yas_max on public.listings
  for each row execute function public.ilan_makul();

-- ============ 4) TEKLİF + MESAJ KORUMASI ============
alter table public.messages add column if not exists tur text not null default 'metin';
alter table public.messages add column if not exists tutar numeric(14,2);
alter table public.messages add column if not exists yanit text;
alter table public.messages drop constraint if exists messages_tur_gecerli;
alter table public.messages add constraint messages_tur_gecerli check (
  tur in ('metin','teklif','teklif_yanit')
  and (tur <> 'teklif' or (tutar is not null and tutar > 0))
  and (yanit is null or yanit in ('kabul','red')));

-- Karşı taraf mesajı sadece "okundu" yapabilir; gövde, tür, tutar, yanıt değiştirilemez (yanıt sadece RPC ile).
create or replace function public.mesaj_koru() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if public.guvenilir() then return new; end if;
  new.body := old.body; new.sender_id := old.sender_id; new.conversation_id := old.conversation_id;
  new.tur := old.tur; new.tutar := old.tutar; new.yanit := old.yanit; new.created_at := old.created_at;
  return new;
end $$;
drop trigger if exists messages_koru on public.messages;
create trigger messages_koru before update on public.messages for each row execute function public.mesaj_koru();

-- Teklif eklerken yanıt alanı boş başlar; kullanıcı kendi teklifine "kabul" yazamaz.
create or replace function public.mesaj_ekle_koru() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not public.guvenilir() then
    new.yanit := null;
    if new.tur = 'teklif_yanit' then new.tur := 'metin'; end if;
  end if;
  return new;
end $$;
drop trigger if exists messages_ekle_koru on public.messages;
create trigger messages_ekle_koru before insert on public.messages for each row execute function public.mesaj_ekle_koru();

-- Teklifi alan taraf kabul eder veya reddeder; cevap mesajı da eklenir.
create or replace function public.teklif_yanitla(p_mesaj uuid, p_kabul boolean) returns void
language plpgsql security definer set search_path = public as $$
declare m public.messages;
begin
  select * into m from public.messages where id = p_mesaj;
  if m.id is null or m.tur <> 'teklif' then raise exception 'teklif bulunamadı'; end if;
  if not public.is_participant(m.conversation_id) or m.sender_id = auth.uid() then
    raise exception 'Bu teklifi sadece karşı taraf yanıtlayabilir.' using errcode = '42501';
  end if;
  if m.yanit is not null then raise exception 'Bu teklif zaten yanıtlandı.'; end if;
  perform set_config('kuzu.guvenilir', '1', true);
  update public.messages set yanit = case when p_kabul then 'kabul' else 'red' end, read_at = coalesce(read_at, now()) where id = p_mesaj;
  insert into public.messages (conversation_id, sender_id, body, tur, tutar)
  values (m.conversation_id, auth.uid(),
          replace(to_char(m.tutar, 'FM999,999,999'), ',', '.') ||
          case when p_kabul then ' ₺ teklifini kabul ettim. Teslim ve ödeme için yazışalım.' else ' ₺ teklifini kabul edemiyorum.' end,
          'teklif_yanit', m.tutar);
  perform set_config('kuzu.guvenilir', '', true);
end $$;
grant execute on function public.teklif_yanitla(uuid, boolean) to authenticated;

-- ============ 5) DESTEK MESAJLARI ============
create table if not exists public.destek_mesajlari (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references auth.users(id) on delete set null,
  konu        text not null check (konu in ('soru','hata','oneri','sikayet','diger')),
  mesaj       text not null check (char_length(mesaj) between 5 and 2000),
  iletisim    text check (iletisim is null or char_length(iletisim) <= 120),
  durum       text not null default 'yeni' check (durum in ('yeni','kapandi')),
  created_at  timestamptz not null default now()
);
alter table public.destek_mesajlari enable row level security;
drop policy if exists destek_ekle on public.destek_mesajlari;
create policy destek_ekle on public.destek_mesajlari for insert to anon, authenticated
  with check (user_id is null or user_id = auth.uid());
drop policy if exists destek_oku on public.destek_mesajlari;
create policy destek_oku on public.destek_mesajlari for select to authenticated using (user_id = auth.uid());
grant insert on public.destek_mesajlari to anon, authenticated;
grant select on public.destek_mesajlari to authenticated;

create or replace function public.yonetici_destek(p_durum text default 'yeni') returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.yonetici_kontrol();
  return coalesce((select jsonb_agg(jsonb_build_object(
      'id', d.id, 'konu', d.konu, 'mesaj', d.mesaj, 'iletisim', d.iletisim, 'durum', d.durum, 'created_at', d.created_at,
      'kullanici', (select jsonb_build_object('id', p.id, 'ad', p.full_name) from public.profiles p where p.id = d.user_id),
      'telefon', (select u.phone from auth.users u where u.id = d.user_id))
    order by d.created_at desc)
    from (select * from public.destek_mesajlari where durum = p_durum order by created_at desc limit 100) d), '[]'::jsonb);
end $$;

create or replace function public.yonetici_destek_durum(p_id uuid, p_durum text) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public.yonetici_kontrol();
  if p_durum not in ('yeni','kapandi') then raise exception 'geçersiz durum'; end if;
  update public.destek_mesajlari set durum = p_durum where id = p_id;
end $$;
revoke all on function public.yonetici_destek(text), public.yonetici_destek_durum(uuid, text) from public, anon;
grant execute on function public.yonetici_destek(text), public.yonetici_destek_durum(uuid, text) to authenticated;

-- Moderasyon özetine destek sayısı (009'daki fonksiyonun yeni hali)
create or replace function public.yonetici_moderasyon_ozet() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.yonetici_kontrol();
  return jsonb_build_object(
    'sikayet_yeni',      (select count(*) from public.reports where status = 'yeni'),
    'sikayet_inceleniyor',(select count(*) from public.reports where status = 'inceleniyor'),
    'onay_bekleyen',     (select count(*) from public.listings where moderasyon = 'onay_bekliyor'),
    'otomatik_gizlenen', (select count(*) from public.listings where moderasyon = 'otomatik_gizlendi'),
    'supheli',           (select count(*) from public.listings l
                           where (l.durum = 'aktif' and l.expires_at > now() or l.moderasyon = 'onay_bekliyor')
                             and cardinality(public.ilan_supheli(l)) > 0),
    'askida_kullanici',  (select count(*) from public.profiles where askida),
    'destek_yeni',       (select count(*) from public.destek_mesajlari where durum = 'yeni'),
    'on_onay',           public.ayar_acik('on_onay')
  );
end $$;

-- ============ 6) ÖRNEK ALICI TALEPLERİ ============
do $$ begin
  if exists (select 1 from public.profiles where id = 'cccccccc-0000-0000-0000-000000000001') then
    insert into public.wanted_ads (id, buyer_id, tur, cins, adet, amac, butce_max, il, aciklama, expires_at) values
      ('eeeeeeee-0000-0000-0000-000000000001', 'cccccccc-0000-0000-0000-000000000001', 'kucukbas', 'Kıvırcık', 2, 'kurbanlik', 45000, 'Ankara',
       '[ÖRNEK TALEP] Kurban için 2 adet erkek kuzu arıyorum, 40-50 kg. Ankara''ya teslim olursa iyi olur.', now() + interval '60 days'),
      ('eeeeeeee-0000-0000-0000-000000000002', 'cccccccc-0000-0000-0000-000000000002', 'buyukbas', 'Simental', 1, 'damizlik', 260000, 'Konya',
       '[ÖRNEK TALEP] Gebe Simental düve arıyorum, aşıları ve küpesi tam olsun.', now() + interval '60 days'),
      ('eeeeeeee-0000-0000-0000-000000000003', 'cccccccc-0000-0000-0000-000000000003', 'kucukbas', null, 25, 'besi', 400000, 'Manisa',
       '[ÖRNEK TALEP] Besiye almak için 20-30 baş toklu arıyorum, Ege bölgesinden.', now() + interval '60 days'),
      ('eeeeeeee-0000-0000-0000-000000000004', 'cccccccc-0000-0000-0000-000000000004', 'kucukbas', 'Saanen', 5, 'sut_yumurta', null, 'İzmir',
       '[ÖRNEK TALEP] Sağmal Saanen keçi arıyorum, verim bilgisi paylaşan satıcı tercihim.', now() + interval '60 days')
    on conflict (id) do nothing;
  end if;
end $$;

-- ============ İL/İLÇE VERİSİ (tool/iller_uret.py --sql ile üretildi) ============
insert into public.ilce_konum (il, ilce, lat, lng, il_lat, il_lng) values
('Adana','Aladağ',37.5504,35.3926,37.0029,35.3194),
('Adana','Ceyhan',37.0259,35.8175,37.0029,35.3194),
('Adana','Çukurova',37.0573,35.2769,37.0029,35.3194),
('Adana','Feke',37.8151,35.9127,37.0029,35.3194),
('Adana','İmamoğlu',37.263,35.6688,37.0029,35.3194),
('Adana','Karaisalı',37.2559,35.0589,37.0029,35.3194),
('Adana','Karataş',36.5641,35.3861,37.0029,35.3194),
('Adana','Kozan',37.4511,35.8131,37.0029,35.3194),
('Adana','Pozantı',37.4221,34.8718,37.0029,35.3194),
('Adana','Saimbeyli',37.9847,36.0885,37.0029,35.3194),
('Adana','Sarıçam',37.0499,35.4589,37.0029,35.3194),
('Adana','Seyhan',36.9831,35.3328,37.0029,35.3194),
('Adana','Tufanbeyli',38.2618,36.221,37.0029,35.3194),
('Adana','Yumurtalık',36.7677,35.7885,37.0029,35.3194),
('Adana','Yüreğir',36.9857,35.3371,37.0029,35.3194),
('Adıyaman','Besni',37.693,37.8618,37.7636,38.2772),
('Adıyaman','Çelikhan',38.0322,38.2349,37.7636,38.2772),
('Adıyaman','Gerger',38.0292,39.0349,37.7636,38.2772),
('Adıyaman','Gölbaşı',37.7845,37.6393,37.7636,38.2772),
('Adıyaman','Kahta',37.7831,38.6209,37.7636,38.2772),
('Adıyaman','Merkez',37.7601,38.2637,37.7636,38.2772),
('Adıyaman','Samsat',37.5775,38.4757,37.7636,38.2772),
('Adıyaman','Sincik',38.0278,38.624,37.7636,38.2772),
('Adıyaman','Tut',37.7901,37.9203,37.7636,38.2772),
('Afyonkarahisar','Başmakçı',37.897,30.0112,38.7568,30.5387),
('Afyonkarahisar','Bayat',38.9843,30.9233,38.7568,30.5387),
('Afyonkarahisar','Bolvadin',38.7056,31.0485,38.7568,30.5387),
('Afyonkarahisar','Çay',38.5932,31.0268,38.7568,30.5387),
('Afyonkarahisar','Çobanlar',38.7004,30.7813,38.7568,30.5387),
('Afyonkarahisar','Dazkırı',37.9194,29.859,38.7568,30.5387),
('Afyonkarahisar','Dinar',38.0683,30.1649,38.7568,30.5387),
('Afyonkarahisar','Emirdağ',39.0195,31.1514,38.7568,30.5387),
('Afyonkarahisar','Evciler',38.0411,29.8861,38.7568,30.5387),
('Afyonkarahisar','Hocalar',38.5798,29.9672,38.7568,30.5387),
('Afyonkarahisar','İhsaniye',39.0382,30.4179,38.7568,30.5387),
('Afyonkarahisar','İscehisar',38.8611,30.7487,38.7568,30.5387),
('Afyonkarahisar','Kızılören',38.2591,30.1518,38.7568,30.5387),
('Afyonkarahisar','Merkez',38.7583,30.5386,38.7568,30.5387),
('Afyonkarahisar','Sandıklı',38.4626,30.2741,38.7568,30.5387),
('Afyonkarahisar','Sinanpaşa',38.746,30.2461,38.7568,30.5387),
('Afyonkarahisar','Şuhut',38.533,30.5441,38.7568,30.5387),
('Afyonkarahisar','Sultandağı',38.532,31.2303,38.7568,30.5387),
('Ağrı','Diyadin',39.5437,43.6697,39.7081,43.0488),
('Ağrı','Doğubayazıt',39.5474,44.0821,39.7081,43.0488),
('Ağrı','Eleşkirt',39.7988,42.6801,39.7081,43.0488),
('Ağrı','Hamur',39.6082,42.9876,39.7081,43.0488),
('Ağrı','Merkez',39.7173,43.0328,39.7081,43.0488),
('Ağrı','Patnos',39.2376,42.8488,39.7081,43.0488),
('Ağrı','Taşlıçay',39.6359,43.3745,39.7081,43.0488),
('Ağrı','Tutak',39.5385,42.7717,39.7081,43.0488),
('Amasya','Göynücek',40.3956,35.5226,40.6522,35.8341),
('Amasya','Gümüşhacıköy',40.8761,35.2181,40.6522,35.8341),
('Amasya','Hamamözü',40.7835,35.0249,40.6522,35.8341),
('Amasya','Merkez',40.6537,35.8339,40.6522,35.8341),
('Amasya','Merzifon',40.8751,35.4597,40.6522,35.8341),
('Amasya','Suluova',40.8275,35.6526,40.6522,35.8341),
('Amasya','Taşova',40.7609,36.3222,40.6522,35.8341),
('Ankara','Akyurt',40.1289,33.0767,39.9207,32.854),
('Ankara','Altındağ',39.9554,32.8551,39.9207,32.854),
('Ankara','Ayaş',40.0176,32.3319,39.9207,32.854),
('Ankara','Bala',39.5588,33.1181,39.9207,32.854),
('Ankara','Beypazarı',40.1645,31.9183,39.9207,32.854),
('Ankara','Çamlıdere',40.4917,32.4763,39.9207,32.854),
('Ankara','Çankaya',39.9193,32.8513,39.9207,32.854),
('Ankara','Çubuk',40.2404,33.0323,39.9207,32.854),
('Ankara','Elmadağ',39.9194,33.2345,39.9207,32.854),
('Ankara','Etimesgut',39.947,32.6697,39.9207,32.854),
('Ankara','Evren',39.0164,33.803,39.9207,32.854),
('Ankara','Gölbaşı',39.7858,32.8086,39.9207,32.854),
('Ankara','Güdül',40.2109,32.244,39.9207,32.854),
('Ankara','Haymana',39.435,32.4962,39.9207,32.854),
('Ankara','Kahramankazan',40.2216,32.6845,39.9207,32.854),
('Ankara','Kalecik',40.0999,33.4077,39.9207,32.854),
('Ankara','Keçiören',39.9786,32.8693,39.9207,32.854),
('Ankara','Kızılcahamam',40.4707,32.6474,39.9207,32.854),
('Ankara','Mamak',39.9327,32.9107,39.9207,32.854),
('Ankara','Nallıhan',40.185,31.3516,39.9207,32.854),
('Ankara','Polatlı',39.5802,32.1322,39.9207,32.854),
('Ankara','Pursaklar',40.0607,32.9174,39.9207,32.854),
('Ankara','Şereflikoçhisar',38.9316,33.551,39.9207,32.854),
('Ankara','Sincan',39.9657,32.5767,39.9207,32.854),
('Ankara','Yenimahalle',39.9665,32.8114,39.9207,32.854),
('Antalya','Akseki',37.0462,31.7903,36.8871,30.7032),
('Antalya','Aksu',36.9474,30.8475,36.8871,30.7032),
('Antalya','Alanya',36.5433,32.003,36.8871,30.7032),
('Antalya','Demre',36.2416,29.9747,36.8871,30.7032),
('Antalya','Döşemealtı',37.0233,30.603,36.8871,30.7032),
('Antalya','Elmalı',36.7336,29.9261,36.8871,30.7032),
('Antalya','Finike',36.2982,30.146,36.8871,30.7032),
('Antalya','Gazipaşa',36.2679,32.3169,36.8871,30.7032),
('Antalya','Gündoğmuş',36.8146,31.9984,36.8871,30.7032),
('Antalya','İbradı',37.0955,31.5954,36.8871,30.7032),
('Antalya','Kaş',36.1984,29.6433,36.8871,30.7032),
('Antalya','Kemer',36.5944,30.5674,36.8871,30.7032),
('Antalya','Kepez',36.9115,30.6812,36.8871,30.7032),
('Antalya','Konyaaltı',36.8758,30.6418,36.8871,30.7032),
('Antalya','Korkuteli',37.066,30.1952,36.8871,30.7032),
('Antalya','Kumluca',36.3713,30.2868,36.8871,30.7032),
('Antalya','Manavgat',36.7863,31.4466,36.8871,30.7032),
('Antalya','Muratpaşa',36.8878,30.7088,36.8871,30.7032),
('Antalya','Serik',36.9167,31.1009,36.8871,30.7032),
('Artvin','Ardanuç',41.1227,42.0659,41.1817,41.821),
('Artvin','Arhavi',41.3528,41.3098,41.1817,41.821),
('Artvin','Borçka',41.3589,41.6762,41.1817,41.821),
('Artvin','Hopa',41.3954,41.4215,41.1817,41.821),
('Artvin','Kemalpaşa',41.4832,41.5232,41.1817,41.821),
('Artvin','Merkez',41.1809,41.8207,41.1817,41.821),
('Artvin','Murgul',41.2771,41.562,41.1817,41.821),
('Artvin','Şavşat',41.2527,42.3572,41.1817,41.821),
('Artvin','Yusufeli',40.8139,41.5372,41.1817,41.821),
('Aydın','Bozdoğan',37.6725,28.3113,37.847,27.8454),
('Aydın','Buharkent',37.9698,28.7436,37.847,27.8454),
('Aydın','Çine',37.6139,28.0635,37.847,27.8454),
('Aydın','Didim',37.3699,27.2646,37.847,27.8454),
('Aydın','Efeler',37.8459,27.8305,37.847,27.8454),
('Aydın','Germencik',37.8722,27.6001,37.847,27.8454),
('Aydın','İncirliova',37.8514,27.7245,37.847,27.8454),
('Aydın','Karacasu',37.7311,28.6059,37.847,27.8454),
('Aydın','Karpuzlu',37.5564,27.8366,37.847,27.8454),
('Aydın','Koçarlı',37.761,27.7071,37.847,27.8454),
('Aydın','Köşk',37.8538,28.0523,37.847,27.8454),
('Aydın','Kuşadası',37.8608,27.2571,37.847,27.8454),
('Aydın','Kuyucak',37.9135,28.4593,37.847,27.8454),
('Aydın','Nazilli',37.9105,28.3284,37.847,27.8454),
('Aydın','Söke',37.7534,27.4032,37.847,27.8454),
('Aydın','Sultanhisar',37.8858,28.1539,37.847,27.8454),
('Aydın','Yenipazar',37.8241,28.1963,37.847,27.8454),
('Balıkesir','Altıeylül',39.6404,27.881,39.6474,27.8879),
('Balıkesir','Ayvalık',39.3229,26.6938,39.6474,27.8879),
('Balıkesir','Balya',39.7494,27.5779,39.6474,27.8879),
('Balıkesir','Bandırma',40.3555,27.972,39.6474,27.8879),
('Balıkesir','Bigadiç',39.3909,28.1317,39.6474,27.8879),
('Balıkesir','Burhaniye',39.5022,26.9783,39.6474,27.8879),
('Balıkesir','Dursunbey',39.5823,28.6278,39.6474,27.8879),
('Balıkesir','Edremit',39.5933,27.023,39.6474,27.8879),
('Balıkesir','Erdek',40.3956,27.7928,39.6474,27.8879),
('Balıkesir','Gömeç',39.3888,26.8396,39.6474,27.8879),
('Balıkesir','Gönen',40.1076,27.6548,39.6474,27.8879),
('Balıkesir','Havran',39.5593,27.101,39.6474,27.8879),
('Balıkesir','İvrindi',39.5819,27.4846,39.6474,27.8879),
('Balıkesir','Karesi',39.6469,27.8851,39.6474,27.8879),
('Balıkesir','Kepsut',39.687,28.1572,39.6474,27.8879),
('Balıkesir','Manyas',40.0465,27.9694,39.6474,27.8879),
('Balıkesir','Marmara',40.5883,27.5572,39.6474,27.8879),
('Balıkesir','Savaştepe',39.3803,27.6543,39.6474,27.8879),
('Balıkesir','Sındırgı',39.239,28.1724,39.6474,27.8879),
('Balıkesir','Susurluk',39.9168,28.1552,39.6474,27.8879),
('Bilecik','Bozüyük',39.9064,30.035,40.1392,29.9763),
('Bilecik','Gölpazarı',40.2822,30.3088,40.1392,29.9763),
('Bilecik','İnhisar',40.0556,30.3843,40.1392,29.9763),
('Bilecik','Merkez',40.145,29.9824,40.1392,29.9763),
('Bilecik','Osmaneli',40.358,30.0162,40.1392,29.9763),
('Bilecik','Pazaryeri',39.9961,29.9026,40.1392,29.9763),
('Bilecik','Söğüt',40.0144,30.1832,40.1392,29.9763),
('Bilecik','Yenipazar',40.1767,30.52,40.1392,29.9763),
('Bingöl','Adaklı',39.2284,40.4813,38.8846,40.4977),
('Bingöl','Genç',38.7481,40.5514,38.8846,40.4977),
('Bingöl','Karlıova',39.2969,41.012,38.8846,40.4977),
('Bingöl','Kiğı',39.3092,40.35,38.8846,40.4977),
('Bingöl','Merkez',38.895,40.5091,38.8846,40.4977),
('Bingöl','Solhan',38.9667,41.0516,38.8846,40.4977),
('Bingöl','Yayladere',39.2264,40.0694,38.8846,40.4977),
('Bingöl','Yedisu',39.4336,40.5476,38.8846,40.4977),
('Bitlis','Adilcevaz',38.8063,42.7382,38.398,42.107),
('Bitlis','Ahlat',38.7544,42.4889,38.398,42.107),
('Bitlis','Güroymak',38.5784,42.0174,38.398,42.107),
('Bitlis','Hizan',38.2225,42.4189,38.398,42.107),
('Bitlis','Merkez',38.428,42.131,38.398,42.107),
('Bitlis','Mutki',38.4088,41.9214,38.398,42.107),
('Bitlis','Tatvan',38.4951,42.2855,38.398,42.107),
('Bolu','Dörtdivan',40.7205,32.0638,40.7328,31.6085),
('Bolu','Gerede',40.7997,32.1943,40.7328,31.6085),
('Bolu','Göynük',40.3992,30.7848,40.7328,31.6085),
('Bolu','Kıbrıscık',40.4097,31.8479,40.7328,31.6085),
('Bolu','Mengen',40.9386,32.0771,40.7328,31.6085),
('Bolu','Merkez',40.7302,31.6006,40.7328,31.6085),
('Bolu','Mudurnu',40.4683,31.21,40.7328,31.6085),
('Bolu','Seben',40.4108,31.5735,40.7328,31.6085),
('Bolu','Yeniçağa',40.771,32.0319,40.7328,31.6085),
('Burdur','Ağlasun',37.6506,30.5317,37.7181,30.2819),
('Burdur','Altınyayla',37.0054,29.5447,37.7181,30.2819),
('Burdur','Bucak',37.4571,30.5874,37.7181,30.2819),
('Burdur','Çavdır',37.1594,29.689,37.7181,30.2819),
('Burdur','Çeltikçi',37.5339,30.4837,37.7181,30.2819),
('Burdur','Gölhisar',37.1423,29.5074,37.7181,30.2819),
('Burdur','Karamanlı',37.3709,29.822,37.7181,30.2819),
('Burdur','Kemer',37.3519,30.0615,37.7181,30.2819),
('Burdur','Merkez',37.7187,30.2828,37.7181,30.2819),
('Burdur','Tefenni',37.3096,29.7724,37.7181,30.2819),
('Burdur','Yeşilova',37.5052,29.7529,37.7181,30.2819),
('Bursa','Büyükorhan',39.7695,28.8877,40.1885,29.0608),
('Bursa','Gemlik',40.4312,29.1545,40.1885,29.0608),
('Bursa','Gürsu',40.2156,29.1948,40.1885,29.0608),
('Bursa','Harmancık',39.6776,29.153,40.1885,29.0608),
('Bursa','İnegöl',40.0743,29.5099,40.1885,29.0608),
('Bursa','İznik',40.4289,29.7261,40.1885,29.0608),
('Bursa','Karacabey',40.2156,28.3597,40.1885,29.0608),
('Bursa','Keles',39.9133,29.2322,40.1885,29.0608),
('Bursa','Kestel',40.1997,29.2132,40.1885,29.0608),
('Bursa','Mudanya',40.3729,28.8891,40.1885,29.0608),
('Bursa','Mustafakemalpaşa',40.036,28.4138,40.1885,29.0608),
('Bursa','Nilüfer',40.2179,28.9851,40.1885,29.0608),
('Bursa','Orhaneli',39.9021,28.9878,40.1885,29.0608),
('Bursa','Orhangazi',40.4861,29.3081,40.1885,29.0608),
('Bursa','Osmangazi',40.19,29.0516,40.1885,29.0608),
('Bursa','Yenişehir',40.2605,29.6499,40.1885,29.0608),
('Bursa','Yıldırım',40.19,29.087,40.1885,29.0608),
('Çanakkale','Ayvacık',39.6009,26.4038,40.1466,26.4086),
('Çanakkale','Bayramiç',39.8101,26.6095,40.1466,26.4086),
('Çanakkale','Biga',40.228,27.2406,40.1466,26.4086),
('Çanakkale','Bozcaada',39.8306,26.0633,40.1466,26.4086),
('Çanakkale','Çan',40.029,27.0496,40.1466,26.4086),
('Çanakkale','Eceabat',40.1813,26.3577,40.1466,26.4086),
('Çanakkale','Ezine',39.7849,26.3343,40.1466,26.4086),
('Çanakkale','Gelibolu',40.4168,26.6721,40.1466,26.4086),
('Çanakkale','Gökçeada',40.1975,25.9024,40.1466,26.4086),
('Çanakkale','Lapseki',40.3467,26.6837,40.1466,26.4086),
('Çanakkale','Merkez',40.1515,26.4059,40.1466,26.4086),
('Çanakkale','Yenice',39.9291,27.2596,40.1466,26.4086),
('Çankırı','Atkaracalar',40.8091,33.077,40.5972,33.6153),
('Çankırı','Bayramören',40.9445,33.1982,40.5972,33.6153),
('Çankırı','Çerkeş',40.8115,32.8908,40.5972,33.6153),
('Çankırı','Eldivan',40.5308,33.4962,40.5972,33.6153),
('Çankırı','Ilgaz',40.9223,33.6262,40.5972,33.6153),
('Çankırı','Kızılırmak',40.3454,33.988,40.5972,33.6153),
('Çankırı','Korgun',40.7345,33.5149,40.5972,33.6153),
('Çankırı','Kurşunlu',40.843,33.2601,40.5972,33.6153),
('Çankırı','Merkez',40.5995,33.6167,40.5972,33.6153),
('Çankırı','Orta',40.6283,33.105,40.5972,33.6153),
('Çankırı','Şabanözü',40.483,33.2825,40.5972,33.6153),
('Çankırı','Yapraklı',40.7559,33.7799,40.5972,33.6153),
('Çorum','Alaca',40.1682,34.8413,40.5498,34.954),
('Çorum','Bayat',40.6437,34.2583,40.5498,34.954),
('Çorum','Boğazkale',40.0254,34.6071,40.5498,34.954),
('Çorum','Dodurga',40.8573,34.8122,40.5498,34.954),
('Çorum','İskilip',40.6834,34.4902,40.5498,34.954),
('Çorum','Kargı',41.1339,34.4847,40.5498,34.954),
('Çorum','Laçin',40.7748,34.8814,40.5498,34.954),
('Çorum','Mecitözü',40.5209,35.2963,40.5498,34.954),
('Çorum','Merkez',40.5536,34.9656,40.5498,34.954),
('Çorum','Oğuzlar',40.7549,34.7023,40.5498,34.954),
('Çorum','Ortaköy',40.2728,35.252,40.5498,34.954),
('Çorum','Osmancık',40.9789,34.8008,40.5498,34.954),
('Çorum','Sungurlu',40.1637,34.3768,40.5498,34.954),
('Çorum','Uğurludağ',40.4462,34.4506,40.5498,34.954),
('Denizli','Acıpayam',37.4266,29.3507,37.783,29.0965),
('Denizli','Babadağ',37.8063,28.8549,37.783,29.0965),
('Denizli','Baklan',37.9764,29.6073,37.783,29.0965),
('Denizli','Bekilli',38.23,29.4186,37.783,29.0965),
('Denizli','Beyağaç',37.2349,28.8961,37.783,29.0965),
('Denizli','Bozkurt',37.8204,29.6079,37.783,29.0965),
('Denizli','Buldan',38.0448,28.8334,37.783,29.0965),
('Denizli','Çal',38.084,29.3976,37.783,29.0965),
('Denizli','Çameli',37.0758,29.346,37.783,29.0965),
('Denizli','Çardak',37.8232,29.6727,37.783,29.0965),
('Denizli','Çivril',38.2964,29.7367,37.783,29.0965),
('Denizli','Güney',38.1586,29.0649,37.783,29.0965),
('Denizli','Honaz',37.7656,29.2802,37.783,29.0965),
('Denizli','Kale',37.4423,28.8445,37.783,29.0965),
('Denizli','Merkezefendi',37.8001,29.0602,37.783,29.0965),
('Denizli','Pamukkale',37.9558,29.0773,37.783,29.0965),
('Denizli','Sarayköy',37.9222,28.9237,37.783,29.0965),
('Denizli','Serinhisar',37.5801,29.2646,37.783,29.0965),
('Denizli','Tavas',37.5711,29.0675,37.783,29.0965),
('Diyarbakır','Bağlar',37.9206,40.197,37.9305,40.1836),
('Diyarbakır','Bismil',37.8515,40.6644,37.9305,40.1836),
('Diyarbakır','Çermik',38.1355,39.4506,37.9305,40.1836),
('Diyarbakır','Çınar',37.7256,40.4149,37.9305,40.1836),
('Diyarbakır','Çüngüş',38.2122,39.2915,37.9305,40.1836),
('Diyarbakır','Dicle',38.3716,40.0708,37.9305,40.1836),
('Diyarbakır','Eğil',38.2598,40.084,37.9305,40.1836),
('Diyarbakır','Ergani',38.2694,39.7584,37.9305,40.1836),
('Diyarbakır','Hani',38.4089,40.3971,37.9305,40.1836),
('Diyarbakır','Hazro',38.2466,40.7801,37.9305,40.1836),
('Diyarbakır','Kayapınar',37.9314,40.1812,37.9305,40.1836),
('Diyarbakır','Kocaköy',38.2917,40.506,37.9305,40.1836),
('Diyarbakır','Kulp',38.499,41.0106,37.9305,40.1836),
('Diyarbakır','Lice',38.4612,40.6465,37.9305,40.1836),
('Diyarbakır','Silvan',38.1427,41.0065,37.9305,40.1836),
('Diyarbakır','Sur',37.9107,40.2418,37.9305,40.1836),
('Diyarbakır','Yenişehir',37.9159,40.2271,37.9305,40.1836),
('Edirne','Enez',40.7247,26.0858,41.6771,26.5556),
('Edirne','Havsa',41.549,26.8235,41.6771,26.5556),
('Edirne','İpsala',40.9224,26.3847,41.6771,26.5556),
('Edirne','Keşan',40.8547,26.6299,41.6771,26.5556),
('Edirne','Lalapaşa',41.839,26.7341,41.6771,26.5556),
('Edirne','Meriç',41.1928,26.4219,41.6771,26.5556),
('Edirne','Merkez',41.6794,26.551,41.6771,26.5556),
('Edirne','Süloğlu',41.7644,26.9062,41.6771,26.5556),
('Edirne','Uzunköprü',41.2662,26.6881,41.6771,26.5556),
('Elazığ','Ağın',38.9445,38.7139,38.675,39.2125),
('Elazığ','Alacakaya',38.4632,39.8616,38.675,39.2125),
('Elazığ','Arıcak',38.5682,40.1378,38.675,39.2125),
('Elazığ','Baskil',38.5673,38.8241,38.675,39.2125),
('Elazığ','Karakoçan',38.9547,40.0382,38.675,39.2125),
('Elazığ','Keban',38.7943,38.7377,38.675,39.2125),
('Elazığ','Kovancılar',38.7209,39.8628,38.675,39.2125),
('Elazığ','Maden',38.3931,39.6663,38.675,39.2125),
('Elazığ','Merkez',38.6748,39.2113,38.675,39.2125),
('Elazığ','Palu',38.6942,39.9297,38.675,39.2125),
('Elazığ','Sivrice',38.448,39.3102,38.675,39.2125),
('Erzincan','Çayırlı',39.8078,40.0382,39.7467,39.491),
('Erzincan','İliç',39.4555,38.5636,39.7467,39.491),
('Erzincan','Kemah',39.6015,39.0333,39.7467,39.491),
('Erzincan','Kemaliye',39.2617,38.4967,39.7467,39.491),
('Erzincan','Merkez',39.7505,39.4895,39.7467,39.491),
('Erzincan','Otlukbeli',39.9705,40.0202,39.7467,39.491),
('Erzincan','Refahiye',39.8996,38.7668,39.7467,39.491),
('Erzincan','Tercan',39.778,40.3875,39.7467,39.491),
('Erzincan','Üzümlü',39.7077,39.6962,39.7467,39.491),
('Erzurum','Aşkale',39.921,40.6919,39.9003,41.2659),
('Erzurum','Aziziye',39.9432,41.1106,39.9003,41.2659),
('Erzurum','Çat',39.6119,40.9767,39.9003,41.2659),
('Erzurum','Hınıs',39.3628,41.6974,39.9003,41.2659),
('Erzurum','Horasan',40.0422,42.1675,39.9003,41.2659),
('Erzurum','İspir',40.4831,41.0002,39.9003,41.2659),
('Erzurum','Karaçoban',39.3472,42.0994,39.9003,41.2659),
('Erzurum','Karayazı',39.7007,42.1416,39.9003,41.2659),
('Erzurum','Köprüköy',39.9662,41.8654,39.9003,41.2659),
('Erzurum','Narman',40.3467,41.8716,39.9003,41.2659),
('Erzurum','Oltu',40.5463,41.9981,39.9003,41.2659),
('Erzurum','Olur',40.8266,42.1324,39.9003,41.2659),
('Erzurum','Palandöken',39.8981,41.2646,39.9003,41.2659),
('Erzurum','Pasinler',39.9746,41.6727,39.9003,41.2659),
('Erzurum','Pazaryolu',40.4147,40.7736,39.9003,41.2659),
('Erzurum','Şenkaya',40.5623,42.3456,39.9003,41.2659),
('Erzurum','Tekman',39.6472,41.5098,39.9003,41.2659),
('Erzurum','Tortum',40.297,41.5513,39.9003,41.2659),
('Erzurum','Uzundere',40.5312,41.5475,39.9003,41.2659),
('Erzurum','Yakutiye',39.9172,41.2793,39.9003,41.2659),
('Eskişehir','Alpu',39.7667,30.959,39.7806,30.5113),
('Eskişehir','Beylikova',39.6884,31.2063,39.7806,30.5113),
('Eskişehir','Çifteler',39.3762,31.0378,39.7806,30.5113),
('Eskişehir','Günyüzü',39.384,31.809,39.7806,30.5113),
('Eskişehir','Han',39.1598,30.8631,39.7806,30.5113),
('Eskişehir','İnönü',39.816,30.1416,39.7806,30.5113),
('Eskişehir','Mahmudiye',39.4934,30.9876,39.7806,30.5113),
('Eskişehir','Mihalgazi',40.0266,30.5765,39.7806,30.5113),
('Eskişehir','Mihalıççık',39.8642,31.4965,39.7806,30.5113),
('Eskişehir','Odunpazarı',39.7699,30.517,39.7806,30.5113),
('Eskişehir','Sarıcakaya',40.0379,30.6217,39.7806,30.5113),
('Eskişehir','Seyitgazi',39.4464,30.697,39.7806,30.5113),
('Eskişehir','Sivrihisar',39.4499,31.5393,39.7806,30.5113),
('Eskişehir','Tepebaşı',39.783,30.5046,39.7806,30.5113),
('Gaziantep','Araban',37.4244,37.6864,37.0626,37.3795),
('Gaziantep','İslahiye',37.0128,36.6233,37.0626,37.3795),
('Gaziantep','Karkamış',36.8362,38.0011,37.0626,37.3795),
('Gaziantep','Nizip',37.0095,37.7941,37.0626,37.3795),
('Gaziantep','Nurdağı',37.1776,36.7292,37.0626,37.3795),
('Gaziantep','Oğuzeli',36.9655,37.5092,37.0626,37.3795),
('Gaziantep','Şahinbey',37.0567,37.3644,37.0626,37.3795),
('Gaziantep','Şehitkamil',37.0699,37.3766,37.0626,37.3795),
('Gaziantep','Yavuzeli',37.3175,37.5681,37.0626,37.3795),
('Giresun','Alucra',40.3201,38.7705,40.9166,38.3817),
('Giresun','Bulancak',40.9352,38.2187,40.9166,38.3817),
('Giresun','Çamoluk',40.1343,38.7334,40.9166,38.3817),
('Giresun','Çanakçı',40.9176,39.009,40.9166,38.3817),
('Giresun','Dereli',40.7376,38.4521,40.9166,38.3817),
('Giresun','Doğankent',40.8115,38.9147,40.9166,38.3817),
('Giresun','Espiye',40.9484,38.7077,40.9166,38.3817),
('Giresun','Eynesil',41.0655,39.1445,40.9166,38.3817),
('Giresun','Görele',41.0327,39.0029,40.9166,38.3817),
('Giresun','Güce',40.8932,38.8045,40.9166,38.3817),
('Giresun','Keşap',40.9167,38.5106,40.9166,38.3817),
('Giresun','Merkez',40.9077,38.3667,40.9166,38.3817),
('Giresun','Piraziz',40.953,38.1257,40.9166,38.3817),
('Giresun','Şebinkarahisar',40.2886,38.4212,40.9166,38.3817),
('Giresun','Tirebolu',41.0081,38.8143,40.9166,38.3817),
('Giresun','Yağlıdere',40.859,38.6275,40.9166,38.3817),
('Gümüşhane','Kelkit',40.1247,39.4364,40.4582,39.4786),
('Gümüşhane','Köse',40.2107,39.6529,40.4582,39.4786),
('Gümüşhane','Kürtün',40.7023,39.0871,40.4582,39.4786),
('Gümüşhane','Merkez',40.4596,39.4815,40.4582,39.4786),
('Gümüşhane','Şiran',40.1915,39.1248,40.4582,39.4786),
('Gümüşhane','Torul',40.5604,39.2965,40.4582,39.4786),
('Hakkari','Çukurca',37.2464,43.6116,37.5693,43.74),
('Hakkari','Derecik',37.0845,44.3103,37.5693,43.74),
('Hakkari','Merkez',37.5779,43.7379,37.5693,43.74),
('Hakkari','Şemdinli',37.3051,44.5738,37.5693,43.74),
('Hakkari','Yüksekova',37.5723,44.2824,37.5693,43.74),
('Hatay','Altınözü',36.1153,36.2483,36.2025,36.1602),
('Hatay','Antakya',36.1989,36.1597,36.2025,36.1602),
('Hatay','Arsuz',36.4333,35.9217,36.2025,36.1602),
('Hatay','Belen',36.4927,36.1931,36.2025,36.1602),
('Hatay','Defne',36.1955,36.1456,36.2025,36.1602),
('Hatay','Dörtyol',36.8349,36.2277,36.2025,36.1602),
('Hatay','Erzin',36.9589,36.1998,36.2025,36.1602),
('Hatay','Hassa',36.8004,36.5175,36.2025,36.1602),
('Hatay','İskenderun',36.5905,36.1731,36.2025,36.1602),
('Hatay','Kırıkhan',36.4984,36.3591,36.2025,36.1602),
('Hatay','Kumlu',36.3645,36.4564,36.2025,36.1602),
('Hatay','Payas',36.7547,36.2035,36.2025,36.1602),
('Hatay','Reyhanlı',36.2634,36.568,36.2025,36.1602),
('Hatay','Samandağ',36.0847,35.9784,36.2025,36.1602),
('Hatay','Yayladağı',35.9024,36.0642,36.2025,36.1602),
('Isparta','Aksu',37.8001,31.0664,37.7635,30.5551),
('Isparta','Atabey',37.9515,30.6383,37.7635,30.5551),
('Isparta','Eğirdir',37.8754,30.8522,37.7635,30.5551),
('Isparta','Gelendost',38.1182,31.0162,37.7635,30.5551),
('Isparta','Gönen',37.9569,30.5131,37.7635,30.5551),
('Isparta','Keçiborlu',37.9476,30.3061,37.7635,30.5551),
('Isparta','Merkez',37.7642,30.5562,37.7635,30.5551),
('Isparta','Şarkikaraağaç',38.0816,31.3641,37.7635,30.5551),
('Isparta','Senirkent',38.1084,30.5525,37.7635,30.5551),
('Isparta','Sütçüler',37.495,30.9816,37.7635,30.5551),
('Isparta','Uluborlu',38.0779,30.45,37.7635,30.5551),
('Isparta','Yalvaç',38.2973,31.1779,37.7635,30.5551),
('Isparta','Yenişarbademli',37.7107,31.392,37.7635,30.5551),
('Mersin','Akdeniz',36.8048,34.6342,36.7895,34.6228),
('Mersin','Anamur',36.0756,32.8366,36.7895,34.6228),
('Mersin','Aydıncık',36.1477,33.3256,36.7895,34.6228),
('Mersin','Bozyazı',36.1059,32.9695,36.7895,34.6228),
('Mersin','Çamlıyayla',37.1681,34.5928,36.7895,34.6228),
('Mersin','Erdemli',36.6061,34.3099,36.7895,34.6228),
('Mersin','Gülnar',36.3386,33.3988,36.7895,34.6228),
('Mersin','Mezitli',36.7591,34.5391,36.7895,34.6228),
('Mersin','Mut',36.642,33.4396,36.7895,34.6228),
('Mersin','Silifke',36.378,33.9271,36.7895,34.6228),
('Mersin','Tarsus',36.9171,34.8956,36.7895,34.6228),
('Mersin','Toroslar',36.8214,34.6118,36.7895,34.6228),
('Mersin','Yenişehir',36.7772,34.5773,36.7895,34.6228),
('İstanbul','Adalar',40.8702,29.1208,41.0112,28.9781),
('İstanbul','Arnavutköy',41.1891,28.7421,41.0112,28.9781),
('İstanbul','Ataşehir',40.9826,29.1079,41.0112,28.9781),
('İstanbul','Avcılar',40.9875,28.7111,41.0112,28.9781),
('İstanbul','Bağcılar',41.0318,28.8489,41.0112,28.9781),
('İstanbul','Bahçelievler',40.9992,28.8509,41.0112,28.9781),
('İstanbul','Bakırköy',40.9819,28.874,41.0112,28.9781),
('İstanbul','Başakşehir',41.1048,28.8015,41.0112,28.9781),
('İstanbul','Bayrampaşa',41.0424,28.9123,41.0112,28.9781),
('İstanbul','Beşiktaş',41.0435,29.0126,41.0112,28.9781),
('İstanbul','Beykoz',41.127,29.0988,41.0112,28.9781),
('İstanbul','Beylikdüzü',40.991,28.6676,41.0112,28.9781),
('İstanbul','Beyoğlu',41.0342,28.9794,41.0112,28.9781),
('İstanbul','Büyükçekmece',41.0211,28.5772,41.0112,28.9781),
('İstanbul','Çatalca',41.1442,28.4606,41.0112,28.9781),
('İstanbul','Çekmeköy',41.0322,29.1708,41.0112,28.9781),
('İstanbul','Esenler',41.0403,28.8726,41.0112,28.9781),
('İstanbul','Esenyurt',41.039,28.6776,41.0112,28.9781),
('İstanbul','Eyüpsultan',41.0461,28.9341,41.0112,28.9781),
('İstanbul','Fatih',41.0223,28.9339,41.0112,28.9781),
('İstanbul','Gaziosmanpaşa',41.0586,28.9115,41.0112,28.9781),
('İstanbul','Güngören',41.0208,28.8727,41.0112,28.9781),
('İstanbul','Kadıköy',40.9863,29.0285,41.0112,28.9781),
('İstanbul','Kağıthane',41.0795,28.9766,41.0112,28.9781),
('İstanbul','Kartal',40.893,29.1925,41.0112,28.9781),
('İstanbul','Küçükçekmece',41.0008,28.7995,41.0112,28.9781),
('İstanbul','Maltepe',40.9183,29.146,41.0112,28.9781),
('İstanbul','Pendik',40.8705,29.2721,41.0112,28.9781),
('İstanbul','Sancaktepe',41.0092,29.2157,41.0112,28.9781),
('İstanbul','Sarıyer',41.132,29.0421,41.0112,28.9781),
('İstanbul','Şile',41.1722,29.6068,41.0112,28.9781),
('İstanbul','Silivri',41.0743,28.2469,41.0112,28.9781),
('İstanbul','Şişli',41.063,28.9874,41.0112,28.9781),
('İstanbul','Sultanbeyli',40.9702,29.2613,41.0112,28.9781),
('İstanbul','Sultangazi',41.1081,28.8775,41.0112,28.9781),
('İstanbul','Tuzla',40.8447,29.2992,41.0112,28.9781),
('İstanbul','Ümraniye',41.0297,29.0997,41.0112,28.9781),
('İstanbul','Üsküdar',41.0207,29.0186,41.0112,28.9781),
('İstanbul','Zeytinburnu',40.9947,28.9047,41.0112,28.9781),
('İzmir','Aliağa',38.8035,26.9706,38.429,27.1342),
('İzmir','Balçova',38.3923,27.048,38.429,27.1342),
('İzmir','Bayındır',38.2203,27.6481,38.429,27.1342),
('İzmir','Bayraklı',38.4496,27.1814,38.429,27.1342),
('İzmir','Bergama',39.1177,27.1765,38.429,27.1342),
('İzmir','Beydağ',38.0877,28.2121,38.429,27.1342),
('İzmir','Bornova',38.4665,27.2199,38.429,27.1342),
('İzmir','Buca',38.3816,27.1631,38.429,27.1342),
('İzmir','Çeşme',38.3245,26.3128,38.429,27.1342),
('İzmir','Çiğli',38.4916,27.0646,38.429,27.1342),
('İzmir','Dikili',39.0726,26.8882,38.429,27.1342),
('İzmir','Foça',38.6734,26.7578,38.429,27.1342),
('İzmir','Gaziemir',38.33,27.1312,38.429,27.1342),
('İzmir','Güzelbahçe',38.3699,26.8931,38.429,27.1342),
('İzmir','Karabağlar',38.399,27.1273,38.429,27.1342),
('İzmir','Karaburun',38.6436,26.5136,38.429,27.1342),
('İzmir','Karşıyaka',38.4593,27.1156,38.429,27.1342),
('İzmir','Kemalpaşa',38.4278,27.4187,38.429,27.1342),
('İzmir','Kınık',39.088,27.3803,38.429,27.1342),
('İzmir','Kiraz',38.2317,28.2067,38.429,27.1342),
('İzmir','Konak',38.4191,27.1299,38.429,27.1342),
('İzmir','Menderes',38.2594,27.1298,38.429,27.1342),
('İzmir','Menemen',38.6121,27.072,38.429,27.1342),
('İzmir','Narlıdere',38.3956,26.9933,38.429,27.1342),
('İzmir','Ödemiş',38.2289,27.9747,38.429,27.1342),
('İzmir','Seferihisar',38.1965,26.8388,38.429,27.1342),
('İzmir','Selçuk',37.9497,27.37,38.429,27.1342),
('İzmir','Tire',38.0894,27.733,38.429,27.1342),
('İzmir','Torbalı',38.1546,27.3578,38.429,27.1342),
('İzmir','Urla',38.3218,26.7619,38.429,27.1342),
('Kars','Akyaka',40.7415,43.6261,40.601,43.1001),
('Kars','Arpaçay',40.846,43.3288,40.601,43.1001),
('Kars','Digor',40.3744,43.4152,40.601,43.1001),
('Kars','Kağızman',40.1413,43.1201,40.601,43.1001),
('Kars','Merkez',40.6006,43.0951,40.601,43.1001),
('Kars','Sarıkamış',40.3312,42.59,40.601,43.1001),
('Kars','Selim',40.4644,42.7886,40.601,43.1001),
('Kars','Susuz',40.779,43.1301,40.601,43.1001),
('Kastamonu','Abana',41.9787,34.0086,41.3764,33.7773),
('Kastamonu','Ağlı',41.688,33.5497,41.3764,33.7773),
('Kastamonu','Araç',41.242,33.3293,41.3764,33.7773),
('Kastamonu','Azdavay',41.6418,33.3013,41.3764,33.7773),
('Kastamonu','Bozkurt',41.9568,34.0112,41.3764,33.7773),
('Kastamonu','Çatalzeytin',41.9534,34.2174,41.3764,33.7773),
('Kastamonu','Cide',41.8927,32.992,41.3764,33.7773),
('Kastamonu','Daday',41.4768,33.4655,41.3764,33.7773),
('Kastamonu','Devrekani',41.602,33.8408,41.3764,33.7773),
('Kastamonu','Doğanyurt',42.0061,33.4627,41.3764,33.7773),
('Kastamonu','Hanönü',41.6261,34.4655,41.3764,33.7773),
('Kastamonu','İhsangazi',41.202,33.5559,41.3764,33.7773),
('Kastamonu','İnebolu',41.9788,33.7616,41.3764,33.7773),
('Kastamonu','Küre',41.8071,33.7114,41.3764,33.7773),
('Kastamonu','Merkez',41.3761,33.779,41.3764,33.7773),
('Kastamonu','Pınarbaşı',41.6044,33.1097,41.3764,33.7773),
('Kastamonu','Şenpazar',41.8123,33.2343,41.3764,33.7773),
('Kastamonu','Seydiler',41.6159,33.722,41.3764,33.7773),
('Kastamonu','Taşköprü',41.5101,34.216,41.3764,33.7773),
('Kastamonu','Tosya',41.0163,34.0379,41.3764,33.7773),
('Kayseri','Akkışla',39.0025,36.1689,38.7218,35.4873),
('Kayseri','Bünyan',38.8461,35.8572,38.7218,35.4873),
('Kayseri','Develi',38.3891,35.4904,38.7218,35.4873),
('Kayseri','Felahiye',39.0899,35.5692,38.7218,35.4873),
('Kayseri','Hacılar',38.6456,35.4503,38.7218,35.4873),
('Kayseri','İncesu',38.6243,35.1854,38.7218,35.4873),
('Kayseri','Kocasinan',38.736,35.4937,38.7218,35.4873),
('Kayseri','Melikgazi',38.7216,35.5007,38.7218,35.4873),
('Kayseri','Özvatan',39.1039,35.7017,38.7218,35.4873),
('Kayseri','Pınarbaşı',38.7194,36.396,38.7218,35.4873),
('Kayseri','Sarıoğlan',39.0772,35.9688,38.7218,35.4873),
('Kayseri','Sarız',38.4807,36.4982,38.7218,35.4873),
('Kayseri','Talas',38.6935,35.5495,38.7218,35.4873),
('Kayseri','Tomarza',38.4474,35.7992,38.7218,35.4873),
('Kayseri','Yahyalı',38.0998,35.3596,38.7218,35.4873),
('Kayseri','Yeşilhisar',38.3509,35.0892,38.7218,35.4873),
('Kırklareli','Babaeski',41.4298,27.0914,41.7355,27.2244),
('Kırklareli','Demirköy',41.8247,27.771,41.7355,27.2244),
('Kırklareli','Kofçaz',41.9426,27.1552,41.7355,27.2244),
('Kırklareli','Lüleburgaz',41.4084,27.3505,41.7355,27.2244),
('Kırklareli','Merkez',41.7339,27.2187,41.7355,27.2244),
('Kırklareli','Pehlivanköy',41.3471,26.917,41.7355,27.2244),
('Kırklareli','Pınarhisar',41.6257,27.5152,41.7355,27.2244),
('Kırklareli','Vize',41.5726,27.7646,41.7355,27.2244),
('Kırşehir','Akçakent',39.6269,34.0987,39.146,34.1605),
('Kırşehir','Akpınar',39.4501,33.9624,39.146,34.1605),
('Kırşehir','Boztepe',39.2671,34.2624,39.146,34.1605),
('Kırşehir','Çiçekdağı',39.6033,34.4164,39.146,34.1605),
('Kırşehir','Kaman',39.3592,33.7178,39.146,34.1605),
('Kırşehir','Merkez',39.1509,34.1595,39.146,34.1605),
('Kırşehir','Mucur',39.0638,34.3745,39.146,34.1605),
('Kocaeli','Başiskele',40.7108,29.93,40.7665,29.9405),
('Kocaeli','Çayırova',40.8596,29.3913,40.7665,29.9405),
('Kocaeli','Darıca',40.7572,29.3862,40.7665,29.9405),
('Kocaeli','Derince',40.7547,29.8134,40.7665,29.9405),
('Kocaeli','Dilovası',40.7961,29.5515,40.7665,29.9405),
('Kocaeli','Gebze',40.7972,29.4369,40.7665,29.9405),
('Kocaeli','Gölcük',40.7216,29.8214,40.7665,29.9405),
('Kocaeli','İzmit',40.772,29.9659,40.7665,29.9405),
('Kocaeli','Kandıra',41.069,30.1523,40.7665,29.9405),
('Kocaeli','Karamürsel',40.6919,29.6169,40.7665,29.9405),
('Kocaeli','Kartepe',40.749,30.0476,40.7665,29.9405),
('Kocaeli','Körfez',40.771,29.7664,40.7665,29.9405),
('Konya','Ahırlı',37.2395,32.1232,37.8749,32.4921),
('Konya','Akören',37.4525,32.3743,37.8749,32.4921),
('Konya','Akşehir',38.3558,31.4212,37.8749,32.4921),
('Konya','Altınekin',38.307,32.8649,37.8749,32.4921),
('Konya','Beyşehir',37.6769,31.7282,37.8749,32.4921),
('Konya','Bozkır',37.1914,32.2502,37.8749,32.4921),
('Konya','Çeltik',39.0253,31.8173,37.8749,32.4921),
('Konya','Cihanbeyli',38.6579,32.9218,37.8749,32.4921),
('Konya','Çumra',37.5699,32.7825,37.8749,32.4921),
('Konya','Derbent',38.013,32.0166,37.8749,32.4921),
('Konya','Derebucak',37.3939,31.5088,37.8749,32.4921),
('Konya','Doğanhisar',38.146,31.6774,37.8749,32.4921),
('Konya','Emirgazi',37.8998,33.8344,37.8749,32.4921),
('Konya','Ereğli',37.5116,34.0517,37.8749,32.4921),
('Konya','Güneysınır',37.2825,32.7192,37.8749,32.4921),
('Konya','Hadim',36.9847,32.4458,37.8749,32.4921),
('Konya','Halkapınar',37.4452,34.1834,37.8749,32.4921),
('Konya','Hüyük',37.9469,31.5951,37.8749,32.4921),
('Konya','Ilgın',38.2792,31.913,37.8749,32.4921),
('Konya','Kadınhanı',38.2407,32.2105,37.8749,32.4921),
('Konya','Karapınar',37.716,33.5498,37.8749,32.4921),
('Konya','Karatay',37.8622,32.5424,37.8749,32.4921),
('Konya','Kulu',39.0972,33.0776,37.8749,32.4921),
('Konya','Meram',37.8672,32.487,37.8749,32.4921),
('Konya','Sarayönü',38.2602,32.406,37.8749,32.4921),
('Konya','Selçuklu',37.881,32.4865,37.8749,32.4921),
('Konya','Seydişehir',37.4206,31.8445,37.8749,32.4921),
('Konya','Taşkent',36.9247,32.4949,37.8749,32.4921),
('Konya','Tuzlukçu',38.4678,31.6221,37.8749,32.4921),
('Konya','Yalıhüyük',37.2955,32.094,37.8749,32.4921),
('Konya','Yunak',38.8163,31.7313,37.8749,32.4921),
('Kütahya','Altıntaş',39.0584,30.1097,39.4192,29.9852),
('Kütahya','Aslanapa',39.2142,29.8695,39.4192,29.9852),
('Kütahya','Çavdarhisar',39.1965,29.6201,39.4192,29.9852),
('Kütahya','Domaniç',39.8014,29.613,39.4192,29.9852),
('Kütahya','Dumlupınar',38.8535,29.978,39.4192,29.9852),
('Kütahya','Emet',39.3442,29.2594,39.4192,29.9852),
('Kütahya','Gediz',38.9895,29.3975,39.4192,29.9852),
('Kütahya','Hisarcık',39.2516,29.223,39.4192,29.9852),
('Kütahya','Merkez',39.4192,29.9847,39.4192,29.9852),
('Kütahya','Pazarlar',38.9958,29.12,39.4192,29.9852),
('Kütahya','Şaphane',39.026,29.2208,39.4192,29.9852),
('Kütahya','Simav',39.0927,28.9789,39.4192,29.9852),
('Kütahya','Tavşanlı',39.5428,29.4907,39.4192,29.9852),
('Malatya','Akçadağ',38.3442,37.9741,38.3517,38.3146),
('Malatya','Arapgir',39.047,38.4946,38.3517,38.3146),
('Malatya','Arguvan',38.7806,38.2647,38.3517,38.3146),
('Malatya','Battalgazi',38.4137,38.3626,38.3517,38.3146),
('Malatya','Darende',38.557,37.493,38.3517,38.3146),
('Malatya','Doğanşehir',38.0913,37.8771,38.3517,38.3146),
('Malatya','Doğanyol',38.3114,39.0382,38.3517,38.3146),
('Malatya','Hekimhan',38.8147,37.9316,38.3517,38.3146),
('Malatya','Kale',38.4067,38.7542,38.3517,38.3146),
('Malatya','Kuluncak',38.8832,37.6706,38.3517,38.3146),
('Malatya','Pütürge',38.1988,38.858,38.3517,38.3146),
('Malatya','Yazıhan',38.5973,38.1838,38.3517,38.3146),
('Malatya','Yeşilyurt',38.2975,38.2476,38.3517,38.3146),
('Manisa','Ahmetli',38.5128,27.9369,38.6181,27.4194),
('Manisa','Akhisar',38.9211,27.8373,38.6181,27.4194),
('Manisa','Alaşehir',38.3541,28.5157,38.6181,27.4194),
('Manisa','Demirci',39.0507,28.6629,38.6181,27.4194),
('Manisa','Gölmarmara',38.7079,27.9171,38.6181,27.4194),
('Manisa','Gördes',38.9346,28.2889,38.6181,27.4194),
('Manisa','Kırkağaç',39.1057,27.6724,38.6181,27.4194),
('Manisa','Köprübaşı',38.7477,28.3993,38.6181,27.4194),
('Manisa','Kula',38.5448,28.6438,38.6181,27.4194),
('Manisa','Salihli',38.4799,28.1312,38.6181,27.4194),
('Manisa','Sarıgöl',38.2315,28.6953,38.6181,27.4194),
('Manisa','Saruhanlı',38.734,27.5666,38.6181,27.4194),
('Manisa','Şehzadeler',38.6138,27.4349,38.6181,27.4194),
('Manisa','Selendi',38.7421,28.8626,38.6181,27.4194),
('Manisa','Soma',39.1817,27.6042,38.6181,27.4194),
('Manisa','Turgutlu',38.4966,27.7053,38.6181,27.4194),
('Manisa','Yunusemre',38.6161,27.4106,38.6181,27.4194),
('Kahramanmaraş','Afşin',38.2382,36.9184,37.5777,36.9237),
('Kahramanmaraş','Andırın',37.5757,36.3488,37.5777,36.9237),
('Kahramanmaraş','Çağlayancerit',37.7471,37.2843,37.5777,36.9237),
('Kahramanmaraş','Dulkadiroğlu',37.5801,36.9289,37.5777,36.9237),
('Kahramanmaraş','Ekinözü',38.0581,37.1876,37.5777,36.9237),
('Kahramanmaraş','Elbistan',38.1953,37.1922,37.5777,36.9237),
('Kahramanmaraş','Göksun',38.0203,36.4955,37.5777,36.9237),
('Kahramanmaraş','Nurhak',37.965,37.4431,37.5777,36.9237),
('Kahramanmaraş','Onikişubat',37.5688,36.8897,37.5777,36.9237),
('Kahramanmaraş','Pazarcık',37.4891,37.2942,37.5777,36.9237),
('Kahramanmaraş','Türkoğlu',37.3781,36.8413,37.5777,36.9237),
('Mardin','Artuklu',37.3356,40.7012,37.3132,40.7349),
('Mardin','Dargeçit',37.5461,41.7135,37.3132,40.7349),
('Mardin','Derik',37.3639,40.2664,37.3132,40.7349),
('Mardin','Kızıltepe',37.1851,40.5954,37.3132,40.7349),
('Mardin','Mazıdağı',37.4773,40.4873,37.3132,40.7349),
('Mardin','Midyat',37.4175,41.3575,37.3132,40.7349),
('Mardin','Nusaybin',37.0784,41.2159,37.3132,40.7349),
('Mardin','Ömerli',37.4041,40.9567,37.3132,40.7349),
('Mardin','Savur',37.5362,40.8868,37.3132,40.7349),
('Mardin','Yeşilli',37.3376,40.8223,37.3132,40.7349),
('Muğla','Bodrum',37.0358,27.4291,37.2151,28.3637),
('Muğla','Dalaman',36.7774,28.8001,37.2151,28.3637),
('Muğla','Datça',36.7259,27.6851,37.2151,28.3637),
('Muğla','Fethiye',36.6228,29.1114,37.2151,28.3637),
('Muğla','Kavaklıdere',37.4471,28.3634,37.2151,28.3637),
('Muğla','Köyceğiz',36.9638,28.6879,37.2151,28.3637),
('Muğla','Marmaris',36.8538,28.2724,37.2151,28.3637),
('Muğla','Menteşe',37.2066,28.3699,37.2151,28.3637),
('Muğla','Milas',37.3103,27.7822,37.2151,28.3637),
('Muğla','Ortaca',36.8329,28.7756,37.2151,28.3637),
('Muğla','Seydikemer',36.6473,29.3624,37.2151,28.3637),
('Muğla','Ula',37.1053,28.4138,37.2151,28.3637),
('Muğla','Yatağan',37.3417,28.137,37.2151,28.3637),
('Muş','Bulanık',39.097,42.2781,38.7376,41.495),
('Muş','Hasköy',38.6873,41.6942,38.7376,41.495),
('Muş','Korkut',38.7353,41.7736,38.7376,41.495),
('Muş','Malazgirt',39.1431,42.5352,38.7376,41.495),
('Muş','Merkez',38.7407,41.4957,38.7376,41.495),
('Muş','Varto',39.1777,41.4479,38.7376,41.495),
('Nevşehir','Acıgöl',38.5506,34.5046,38.6267,34.7199),
('Nevşehir','Avanos',38.7176,34.8459,38.6267,34.7199),
('Nevşehir','Derinkuyu',38.3807,34.7345,38.6267,34.7199),
('Nevşehir','Gülşehir',38.746,34.6185,38.6267,34.7199),
('Nevşehir','Hacıbektaş',38.9409,34.5596,38.6267,34.7199),
('Nevşehir','Kozaklı',39.2173,34.851,38.6267,34.7199),
('Nevşehir','Merkez',38.6268,34.7213,38.6267,34.7199),
('Nevşehir','Ürgüp',38.6317,34.9143,38.6267,34.7199),
('Niğde','Altunhisar',38.0029,34.363,37.9694,34.6757),
('Niğde','Bor',37.8887,34.5542,37.9694,34.6757),
('Niğde','Çamardı',37.8325,34.9869,37.9694,34.6757),
('Niğde','Çiftlik',38.1849,34.4835,37.9694,34.6757),
('Niğde','Merkez',37.9707,34.6757,37.9694,34.6757),
('Niğde','Ulukışla',37.5481,34.4828,37.9694,34.6757),
('Ordu','Akkuş',40.7904,37.018,40.9752,37.9011),
('Ordu','Altınordu',40.9855,37.8742,40.9752,37.9011),
('Ordu','Aybastı',40.6854,37.3996,40.9752,37.9011),
('Ordu','Çamaş',40.9065,37.5243,40.9752,37.9011),
('Ordu','Çatalpınar',40.8786,37.454,40.9752,37.9011),
('Ordu','Çaybaşı',41.0178,37.0995,40.9752,37.9011),
('Ordu','Fatsa',41.0334,37.4963,40.9752,37.9011),
('Ordu','Gölköy',40.6887,37.6186,40.9752,37.9011),
('Ordu','Gülyalı',40.964,38.0525,40.9752,37.9011),
('Ordu','Gürgentepe',40.792,37.5978,40.9752,37.9011),
('Ordu','İkizce',41.0526,37.077,40.9752,37.9011),
('Ordu','Kabadüz',40.8603,37.8909,40.9752,37.9011),
('Ordu','Kabataş',40.7513,37.4504,40.9752,37.9011),
('Ordu','Korgan',40.8322,37.3427,40.9752,37.9011),
('Ordu','Kumru',40.874,37.2645,40.9752,37.9011),
('Ordu','Mesudiye',40.4635,37.7715,40.9752,37.9011),
('Ordu','Perşembe',41.0632,37.7749,40.9752,37.9011),
('Ordu','Ulubey',40.8746,37.7581,40.9752,37.9011),
('Ordu','Ünye',41.131,37.2856,40.9752,37.9011),
('Rize','Ardeşen',41.1913,40.9891,41.0258,40.5166),
('Rize','Çamlıhemşin',41.0489,41.0032,41.0258,40.5166),
('Rize','Çayeli',41.0894,40.7249,41.0258,40.5166),
('Rize','Derepazarı',41.0247,40.4249,41.0258,40.5166),
('Rize','Fındıklı',41.2736,41.1449,41.0258,40.5166),
('Rize','Güneysu',40.977,40.6135,41.0258,40.5166),
('Rize','Hemşin',41.0468,40.8986,41.0258,40.5166),
('Rize','İkizdere',40.7779,40.5602,41.0258,40.5166),
('Rize','İyidere',41.0119,40.3623,41.0258,40.5166),
('Rize','Kalkandere',40.9289,40.4421,41.0258,40.5166),
('Rize','Merkez',41.0288,40.5157,41.0258,40.5166),
('Rize','Pazar',41.1802,40.887,41.0258,40.5166),
('Sakarya','Adapazarı',40.7825,30.4111,40.7761,30.401),
('Sakarya','Akyazı',40.6863,30.6235,40.7761,30.401),
('Sakarya','Arifiye',40.7127,30.3619,40.7761,30.401),
('Sakarya','Erenler',40.7459,30.416,40.7761,30.401),
('Sakarya','Ferizli',40.9504,30.495,40.7761,30.401),
('Sakarya','Geyve',40.509,30.2854,40.7761,30.401),
('Sakarya','Hendek',40.7943,30.7423,40.7761,30.401),
('Sakarya','Karapürçek',40.6442,30.5456,40.7761,30.401),
('Sakarya','Karasu',41.0994,30.6917,40.7761,30.401),
('Sakarya','Kaynarca',41.034,30.3049,40.7761,30.401),
('Sakarya','Kocaali',41.0593,30.8477,40.7761,30.401),
('Sakarya','Pamukova',40.5055,30.1554,40.7761,30.401),
('Sakarya','Sapanca',40.6922,30.2627,40.7761,30.401),
('Sakarya','Serdivan',40.7616,30.3541,40.7761,30.401),
('Sakarya','Söğütlü',40.9051,30.4731,40.7761,30.401),
('Sakarya','Taraklı',40.3981,30.5031,40.7761,30.401),
('Samsun','19 Mayıs',41.4943,36.0812,41.2903,36.3337),
('Samsun','Alaçam',41.6085,35.5998,41.2903,36.3337),
('Samsun','Asarcık',41.0421,36.2377,41.2903,36.3337),
('Samsun','Atakum',41.3294,36.2845,41.2903,36.3337),
('Samsun','Ayvacık',40.9901,36.6324,41.2903,36.3337),
('Samsun','Bafra',41.5687,35.9032,41.2903,36.3337),
('Samsun','Canik',41.2668,36.3492,41.2903,36.3337),
('Samsun','Çarşamba',41.196,36.7268,41.2903,36.3337),
('Samsun','Havza',40.9654,35.6664,41.2903,36.3337),
('Samsun','İlkadım',41.2897,36.3387,41.2903,36.3337),
('Samsun','Kavak',41.0773,36.0425,41.2903,36.3337),
('Samsun','Ladik',40.9133,35.8897,41.2903,36.3337),
('Samsun','Salıpazarı',41.084,36.8228,41.2903,36.3337),
('Samsun','Tekkeköy',41.2124,36.4593,41.2903,36.3337),
('Samsun','Terme',41.2093,36.9709,41.2903,36.3337),
('Samsun','Vezirköprü',41.1431,35.4592,41.2903,36.3337),
('Samsun','Yakakent',41.6316,35.5303,41.2903,36.3337),
('Siirt','Baykan',38.1621,41.7824,37.9257,41.9419),
('Siirt','Eruh',37.7504,42.1802,37.9257,41.9419),
('Siirt','Kurtalan',37.9241,41.6969,37.9257,41.9419),
('Siirt','Merkez',37.9384,41.9237,37.9257,41.9419),
('Siirt','Pervari',37.9336,42.5469,37.9257,41.9419),
('Siirt','Şirvan',38.058,42.0349,37.9257,41.9419),
('Siirt','Tillo',37.9509,42.0108,37.9257,41.9419),
('Sinop','Ayancık',41.9475,34.583,42.0265,35.1511),
('Sinop','Boyabat',41.4654,34.7714,42.0265,35.1511),
('Sinop','Dikmen',41.6513,35.2677,42.0265,35.1511),
('Sinop','Durağan',41.4155,35.0582,42.0265,35.1511),
('Sinop','Erfelek',41.8795,34.9064,42.0265,35.1511),
('Sinop','Gerze',41.8033,35.1981,42.0265,35.1511),
('Sinop','Merkez',42.0273,35.1517,42.0265,35.1511),
('Sinop','Saraydüzü',41.3299,34.8503,42.0265,35.1511),
('Sinop','Türkeli',41.9461,34.3349,42.0265,35.1511),
('Sivas','Akıncılar',40.0788,38.3466,39.7504,37.015),
('Sivas','Altınyayla',39.2732,36.7468,39.7504,37.015),
('Sivas','Divriği',39.3706,38.118,39.7504,37.015),
('Sivas','Doğanşar',40.2141,37.5398,39.7504,37.015),
('Sivas','Gemerek',39.1834,36.0707,39.7504,37.015),
('Sivas','Gölova',40.0609,38.6109,39.7504,37.015),
('Sivas','Gürün',38.7223,37.279,39.7504,37.015),
('Sivas','Hafik',39.8546,37.3925,39.7504,37.015),
('Sivas','İmranlı',39.8734,38.1116,39.7504,37.015),
('Sivas','Kangal',39.2373,37.3938,39.7504,37.015),
('Sivas','Koyulhisar',40.3013,37.8331,39.7504,37.015),
('Sivas','Merkez',39.7625,37.0162,39.7504,37.015),
('Sivas','Şarkışla',39.3494,36.4105,39.7504,37.015),
('Sivas','Suşehri',40.1631,38.089,39.7504,37.015),
('Sivas','Ulaş',39.4478,37.0392,39.7504,37.015),
('Sivas','Yıldızeli',39.8712,36.5952,39.7504,37.015),
('Sivas','Zara',39.8888,37.7418,39.7504,37.015),
('Tekirdağ','Çerkezköy',41.2814,28.0016,40.9763,27.5156),
('Tekirdağ','Çorlu',41.1454,27.8306,40.9763,27.5156),
('Tekirdağ','Ergene',41.2075,27.7457,40.9763,27.5156),
('Tekirdağ','Hayrabolu',41.213,27.1075,40.9763,27.5156),
('Tekirdağ','Kapaklı',41.3296,27.9738,40.9763,27.5156),
('Tekirdağ','Malkara',40.8938,26.9031,40.9763,27.5156),
('Tekirdağ','Marmaraereğlisi',40.9751,27.9447,40.9763,27.5156),
('Tekirdağ','Muratlı',41.1709,27.4984,40.9763,27.5156),
('Tekirdağ','Saray',41.4448,27.9168,40.9763,27.5156),
('Tekirdağ','Şarköy',40.6162,27.1011,40.9763,27.5156),
('Tekirdağ','Süleymanpaşa',40.978,27.5172,40.9763,27.5156),
('Tokat','Almus',40.3754,36.9034,40.3139,36.5517),
('Tokat','Artova',40.1153,36.3001,40.3139,36.5517),
('Tokat','Başçiftlik',40.5467,37.1671,40.3139,36.5517),
('Tokat','Erbaa',40.6734,36.565,40.3139,36.5517),
('Tokat','Merkez',40.3143,36.5523,40.3139,36.5517),
('Tokat','Niksar',40.5906,36.9431,40.3139,36.5517),
('Tokat','Pazar',40.2766,36.2851,40.3139,36.5517),
('Tokat','Reşadiye',40.3982,37.3279,40.3139,36.5517),
('Tokat','Sulusaray',39.9965,36.0949,40.3139,36.5517),
('Tokat','Turhal',40.3848,36.066,40.3139,36.5517),
('Tokat','Yeşilyurt',40.0076,36.2214,40.3139,36.5517),
('Tokat','Zile',40.2967,35.8874,40.3139,36.5517),
('Trabzon','Akçaabat',41.023,39.5677,41.0034,39.7241),
('Trabzon','Araklı',40.9402,40.0544,41.0034,39.7241),
('Trabzon','Arsin',40.9535,39.9377,41.0034,39.7241),
('Trabzon','Beşikdüzü',41.0528,39.2319,41.0034,39.7241),
('Trabzon','Çarşıbaşı',41.0822,39.3774,41.0034,39.7241),
('Trabzon','Çaykara',40.7466,40.2419,41.0034,39.7241),
('Trabzon','Dernekpazarı',40.7998,40.2474,41.0034,39.7241),
('Trabzon','Düzköy',40.8757,39.4259,41.0034,39.7241),
('Trabzon','Hayrat',40.8893,40.37,41.0034,39.7241),
('Trabzon','Köprübaşı',40.8095,40.1237,41.0034,39.7241),
('Trabzon','Maçka',40.8101,39.6134,41.0034,39.7241),
('Trabzon','Of',40.9469,40.2716,41.0034,39.7241),
('Trabzon','Ortahisar',41.0065,39.7192,41.0034,39.7241),
('Trabzon','Şalpazarı',40.9426,39.1945,41.0034,39.7241),
('Trabzon','Sürmene',40.9108,40.1207,41.0034,39.7241),
('Trabzon','Tonya',40.885,39.2903,41.0034,39.7241),
('Trabzon','Vakfıkebir',41.0479,39.2752,41.0034,39.7241),
('Trabzon','Yomra',40.9552,39.866,41.0034,39.7241),
('Tunceli','Çemişgezek',39.0625,38.9156,39.1065,39.5476),
('Tunceli','Hozat',39.106,39.2203,39.1065,39.5476),
('Tunceli','Mazgirt',39.0191,39.6062,39.1065,39.5476),
('Tunceli','Merkez',39.0751,39.534,39.1065,39.5476),
('Tunceli','Nazımiye',39.1815,39.828,39.1065,39.5476),
('Tunceli','Ovacık',39.3581,39.217,39.1065,39.5476),
('Tunceli','Pertek',38.8658,39.3267,39.1065,39.5476),
('Tunceli','Pülümür',39.485,39.8978,39.1065,39.5476),
('Şanlıurfa','Akçakale',36.7093,38.9482,37.1603,38.7914),
('Şanlıurfa','Birecik',37.0172,37.9724,37.1603,38.7914),
('Şanlıurfa','Bozova',37.3628,38.5278,37.1603,38.7914),
('Şanlıurfa','Ceylanpınar',36.8468,40.0539,37.1603,38.7914),
('Şanlıurfa','Eyyübiye',37.1159,38.8204,37.1603,38.7914),
('Şanlıurfa','Halfeti',37.2294,37.9461,37.1603,38.7914),
('Şanlıurfa','Haliliye',37.16,38.8028,37.1603,38.7914),
('Şanlıurfa','Harran',36.8637,39.0216,37.1603,38.7914),
('Şanlıurfa','Hilvan',37.5857,38.9539,37.1603,38.7914),
('Şanlıurfa','Karaköprü',37.2136,38.7987,37.1603,38.7914),
('Şanlıurfa','Siverek',37.7508,39.3194,37.1603,38.7914),
('Şanlıurfa','Suruç',36.9764,38.4243,37.1603,38.7914),
('Şanlıurfa','Viranşehir',37.2252,39.7488,37.1603,38.7914),
('Uşak','Banaz',38.7363,29.7572,38.6739,29.4055),
('Uşak','Eşme',38.3993,28.9679,38.6739,29.4055),
('Uşak','Karahallı',38.3229,29.5344,38.6739,29.4055),
('Uşak','Merkez',38.6735,29.4052,38.6739,29.4055),
('Uşak','Sivaslı',38.498,29.6799,38.6739,29.4055),
('Uşak','Ulubey',38.4167,29.2876,38.6739,29.4055),
('Van','Bahçesaray',38.1198,42.8092,38.4996,43.3952),
('Van','Başkale',38.047,44.0183,38.4996,43.3952),
('Van','Çaldıran',39.135,43.9001,38.4996,43.3952),
('Van','Çatak',38.0074,43.061,38.4996,43.3952),
('Van','Edremit',38.426,43.2619,38.4996,43.3952),
('Van','Erciş',39.0283,43.3625,38.4996,43.3952),
('Van','Gevaş',38.2989,43.1074,38.4996,43.3952),
('Van','Gürpınar',38.3238,43.4089,38.4996,43.3952),
('Van','İpekyolu',38.503,43.3973,38.4996,43.3952),
('Van','Muradiye',38.9874,43.7599,38.4996,43.3952),
('Van','Özalp',38.6578,43.988,38.4996,43.3952),
('Van','Saray',38.6481,44.1729,38.4996,43.3952),
('Van','Tuşba',38.504,43.3729,38.4996,43.3952),
('Yozgat','Akdağmadeni',39.6608,35.8841,39.8224,34.8082),
('Yozgat','Aydıncık',40.1327,35.2881,39.8224,34.8082),
('Yozgat','Boğazlıyan',39.1931,35.2468,39.8224,34.8082),
('Yozgat','Çandır',39.2458,35.5141,39.8224,34.8082),
('Yozgat','Çayıralan',39.3066,35.6532,39.8224,34.8082),
('Yozgat','Çekerek',40.0683,35.4951,39.8224,34.8082),
('Yozgat','Kadışehri',39.994,35.7907,39.8224,34.8082),
('Yozgat','Merkez',39.8285,34.8213,39.8224,34.8082),
('Yozgat','Saraykent',39.6758,35.5153,39.8224,34.8082),
('Yozgat','Sarıkaya',39.4948,35.3733,39.8224,34.8082),
('Yozgat','Şefaatli',39.4979,34.7584,39.8224,34.8082),
('Yozgat','Sorgun',39.8102,35.1825,39.8224,34.8082),
('Yozgat','Yenifakılı',39.2099,35.0063,39.8224,34.8082),
('Yozgat','Yerköy',39.6412,34.4691,39.8224,34.8082),
('Zonguldak','Alaplı',41.1778,31.3892,41.4523,31.7878),
('Zonguldak','Çaycuma',41.4289,32.0744,41.4523,31.7878),
('Zonguldak','Devrek',41.2192,31.9567,41.4523,31.7878),
('Zonguldak','Ereğli',41.2785,31.4228,41.4523,31.7878),
('Zonguldak','Gökçebey',41.3061,32.1418,41.4523,31.7878),
('Zonguldak','Kilimli',41.4924,31.8395,41.4523,31.7878),
('Zonguldak','Kozlu',41.4361,31.7425,41.4523,31.7878),
('Zonguldak','Merkez',41.455,31.7884,41.4523,31.7878),
('Aksaray','Ağaçören',38.8693,33.9181,38.3708,34.0272),
('Aksaray','Eskil',38.4003,33.4135,38.3708,34.0272),
('Aksaray','Gülağaç',38.3938,34.3465,38.3708,34.0272),
('Aksaray','Güzelyurt',38.272,34.3749,38.3708,34.0272),
('Aksaray','Merkez',38.3941,34.0282,38.3708,34.0272),
('Aksaray','Ortaköy',38.7366,34.0383,38.3708,34.0272),
('Aksaray','Sarıyahşi',38.9791,33.8417,38.3708,34.0272),
('Aksaray','Sultanhanı',38.2498,33.5452,38.3708,34.0272),
('Bayburt','Aydıntepe',40.3902,40.1472,40.2605,40.2272),
('Bayburt','Demirözü',40.1661,39.8937,40.2605,40.2272),
('Bayburt','Merkez',40.2594,40.2266,40.2605,40.2272),
('Karaman','Ayrancı',37.362,33.6885,37.1811,33.2222),
('Karaman','Başyayla',36.7521,32.6823,37.1811,33.2222),
('Karaman','Ermenek',36.6405,32.8931,37.1811,33.2222),
('Karaman','Kazımkarabekir',37.2296,32.9618,37.1811,33.2222),
('Karaman','Merkez',37.17,33.2214,37.1811,33.2222),
('Karaman','Sarıveliler',36.6966,32.6177,37.1811,33.2222),
('Kırıkkale','Bahşılı',39.8127,33.4747,39.8393,33.5061),
('Kırıkkale','Balışeyh',39.9097,33.7168,39.8393,33.5061),
('Kırıkkale','Çelebi',39.4656,33.5249,39.8393,33.5061),
('Kırıkkale','Delice',39.9439,34.0311,39.8393,33.5061),
('Kırıkkale','Karakeçili',39.5962,33.3826,39.8393,33.5061),
('Kırıkkale','Keskin',39.6727,33.6141,39.8393,33.5061),
('Kırıkkale','Merkez',39.839,33.4962,39.8393,33.5061),
('Kırıkkale','Sulakyurt',40.1599,33.7182,39.8393,33.5061),
('Kırıkkale','Yahşihan',39.8608,33.4527,39.8393,33.5061),
('Batman','Beşiri',37.9181,41.2918,37.8795,41.1241),
('Batman','Gercüş',37.569,41.3857,37.8795,41.1241),
('Batman','Hasankeyf',37.731,41.417,37.8795,41.1241),
('Batman','Kozluk',38.1727,41.503,37.8795,41.1241),
('Batman','Merkez',37.8995,41.1295,37.8795,41.1241),
('Batman','Sason',38.3325,41.4161,37.8795,41.1241),
('Şırnak','Beytüşşebap',37.5704,43.1663,37.5179,42.4634),
('Şırnak','Cizre',37.3281,42.1877,37.5179,42.4634),
('Şırnak','Güçlükonak',37.4714,41.9105,37.5179,42.4634),
('Şırnak','İdil',37.3408,41.8922,37.5179,42.4634),
('Şırnak','Merkez',37.5229,42.4533,37.5179,42.4634),
('Şırnak','Silopi',37.248,42.4672,37.5179,42.4634),
('Şırnak','Uludere',37.4453,42.8573,37.5179,42.4634),
('Bartın','Amasra',41.7483,32.3861,41.6322,32.3364),
('Bartın','Kurucaşile',41.8452,32.7181,41.6322,32.3364),
('Bartın','Merkez',41.6258,32.3295,41.6322,32.3364),
('Bartın','Ulus',41.584,32.6394,41.6322,32.3364),
('Ardahan','Çıldır',41.1272,43.1347,41.1129,42.7023),
('Ardahan','Damal',41.3404,42.8381,41.1129,42.7023),
('Ardahan','Göle',40.7937,42.61,41.1129,42.7023),
('Ardahan','Hanak',41.2365,42.8461,41.1129,42.7023),
('Ardahan','Merkez',41.1108,42.7022,41.1129,42.7023),
('Ardahan','Posof',41.509,42.7278,41.1129,42.7023),
('Iğdır','Aralık',39.8735,44.5155,39.92,44.0436),
('Iğdır','Karakoyunlu',39.972,44.1726,39.92,44.0436),
('Iğdır','Merkez',39.9236,44.0467,39.92,44.0436),
('Iğdır','Tuzluca',40.0432,43.661,39.92,44.0436),
('Yalova','Altınova',40.6933,29.5087,40.6566,29.2837),
('Yalova','Armutlu',40.5172,28.8274,40.6566,29.2837),
('Yalova','Çiftlikköy',40.6606,29.3252,40.6566,29.2837),
('Yalova','Çınarcık',40.6425,29.1193,40.6566,29.2837),
('Yalova','Merkez',40.6579,29.2733,40.6566,29.2837),
('Yalova','Termal',40.6096,29.1736,40.6566,29.2837),
('Karabük','Eflani',41.4231,32.9559,41.2058,32.6232),
('Karabük','Eskipazar',40.9421,32.5318,41.2058,32.6232),
('Karabük','Merkez',41.201,32.6257,41.2058,32.6232),
('Karabük','Ovacık',41.0752,32.9192,41.2058,32.6232),
('Karabük','Safranbolu',41.2548,32.6761,41.2058,32.6232),
('Karabük','Yenice',41.2006,32.3286,41.2058,32.6232),
('Kilis','Elbeyli',36.6749,37.4672,36.7165,37.1145),
('Kilis','Merkez',36.7155,37.1133,36.7165,37.1145),
('Kilis','Musabeyli',36.8873,36.9205,36.7165,37.1145),
('Kilis','Polateli',36.8421,37.1435,36.7165,37.1145),
('Osmaniye','Bahçe',37.2012,36.5774,37.073,36.2453),
('Osmaniye','Düziçi',37.2482,36.4618,37.073,36.2453),
('Osmaniye','Hasanbeyli',37.1305,36.5506,37.073,36.2453),
('Osmaniye','Kadirli',37.3724,36.0987,37.073,36.2453),
('Osmaniye','Merkez',37.0662,36.233,37.073,36.2453),
('Osmaniye','Sumbas',37.4534,36.0246,37.073,36.2453),
('Osmaniye','Toprakkale',37.0669,36.1469,37.073,36.2453),
('Düzce','Akçakoca',41.0891,31.1255,40.8394,31.1601),
('Düzce','Çilimli',40.892,31.0452,40.8394,31.1601),
('Düzce','Cumayeri',40.8727,30.9518,40.8394,31.1601),
('Düzce','Gölyaka',40.7763,30.9975,40.8394,31.1601),
('Düzce','Gümüşova',40.8468,30.9369,40.8394,31.1601),
('Düzce','Kaynaşlı',40.7719,31.3183,40.8394,31.1601),
('Düzce','Merkez',40.8384,31.1546,40.8394,31.1601),
('Düzce','Yığılca',40.9597,31.4448,40.8394,31.1601)
on conflict (il, ilce) do update set lat = excluded.lat, lng = excluded.lng, il_lat = excluded.il_lat, il_lng = excluded.il_lng;

-- Mevcut kayıtları düzelt: il/ilçe resmi yazılışa, ilanlara konum (güvenilir işlem: makul değer denetimi uygulanmaz)
do $$ begin
  perform set_config('kuzu.guvenilir', '1', true);
  update public.listings set il = il;
  update public.listings set cins = 'Dağlıç' where cins = 'Daglıç';
  update public.profiles set il = il;
  update public.wanted_ads set il = il;
  perform set_config('kuzu.guvenilir', '', true);
end $$;
