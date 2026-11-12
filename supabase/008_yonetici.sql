-- Kuzu Deposu: YÖNETİCİ PANELİ. 007'den sonra çalıştır. Tekrar çalıştırılabilir.
-- 1) Yönetici listesi (admins): sadece buradaki hesaplar paneli görür. Tabloya uygulamadan erişilemez.
-- 2) Uygulama kullanım sayımı (app_visits): her cihaz günde bir kez, anonim cihaz kimliğiyle kaydedilir
--    (giriş yapmayan misafirler de sayılır). Telefon numarası veya konum tutulmaz.
-- 3) yonetici_ozet(): paneldeki tüm sayılar. Yönetici değilsen hata verir.
-- Örnek (seed) hesaplar (aaaaaaaa-… satıcılar, cccccccc-… alıcılar) ve onların ilan/sohbet/yorumları
-- "gerçek" sayılara katılmaz; örnek aktif ilan sayısı ayrıca gösterilir.

-- ============ YÖNETİCİLER ============
create table if not exists public.admins (
  user_id     uuid primary key references auth.users(id) on delete cascade,
  created_at  timestamptz not null default now()
);
alter table public.admins enable row level security;
-- Politika yok: uygulamadan okunamaz/yazılamaz. Sadece aşağıdaki fonksiyonlar (security definer) bakar.
revoke all on public.admins from anon, authenticated;

create or replace function public.yonetici_mi() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.admins where user_id = auth.uid());
$$;
grant execute on function public.yonetici_mi() to authenticated;

-- ============ KULLANIM SAYIMI ============
create table if not exists public.app_visits (
  cihaz_id    text not null check (char_length(cihaz_id) between 8 and 64),
  gun         date not null default (now() at time zone 'Europe/Istanbul')::date,
  user_id     uuid references auth.users(id) on delete set null,
  platform    text not null default 'web' check (platform in ('web','ios','android','diger')),
  ilk_saat    timestamptz not null default now(),
  primary key (cihaz_id, gun)
);
create index if not exists app_visits_gun on public.app_visits (gun);
alter table public.app_visits enable row level security;
revoke all on public.app_visits from anon, authenticated;

-- Uygulama her açılışta çağırır; aynı cihaz aynı gün tekrar sayılmaz. Giriş yapılırsa kullanıcıyla eşlenir.
create or replace function public.ziyaret_kaydet(p_cihaz text, p_platform text default 'web') returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_cihaz is null or char_length(p_cihaz) not between 8 and 64 then return; end if;
  insert into public.app_visits (cihaz_id, user_id, platform)
  values (p_cihaz, auth.uid(), case when p_platform in ('web','ios','android') then p_platform else 'diger' end)
  on conflict (cihaz_id, gun) do update
    set user_id = coalesce(public.app_visits.user_id, excluded.user_id);
end $$;
grant execute on function public.ziyaret_kaydet(text, text) to anon, authenticated;

-- ============ ÖRNEK HESAP AYIRICI ============
create or replace function public.ornek_hesap(p uuid) returns boolean
language sql immutable as $$
  select p::text like 'aaaaaaaa-0000-0000-0000-%' or p::text like 'cccccccc-0000-0000-0000-%';
$$;

-- ============ PANEL ÖZETİ ============
create or replace function public.yonetici_ozet() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  bugun date := (now() at time zone 'Europe/Istanbul')::date;
  sonuc jsonb;
begin
  if not public.yonetici_mi() then
    raise exception 'yetki yok: bu bilgiler sadece yöneticiye açık' using errcode = '42501';
  end if;

  with
  gercek_profil as (select * from public.profiles where not public.ornek_hesap(id)),
  gercek_ilan   as (select * from public.listings where not public.ornek_hesap(seller_id)),
  gercek_sohbet as (select * from public.conversations where not public.ornek_hesap(buyer_id) and not public.ornek_hesap(seller_id)),
  gercek_mesaj  as (select m.* from public.messages m join gercek_sohbet c on c.id = m.conversation_id),
  gunler as (select generate_series(bugun - 13, bugun, interval '1 day')::date as g)
  select jsonb_build_object(
    'kullanim', jsonb_build_object(
      'toplam_cihaz', (select count(distinct cihaz_id) from public.app_visits),
      'bugun',        (select count(*) from public.app_visits where gun = bugun),
      'son7',         (select count(distinct cihaz_id) from public.app_visits where gun > bugun - 7),
      'son30',        (select count(distinct cihaz_id) from public.app_visits where gun > bugun - 30),
      'misafir_bugun',(select count(*) from public.app_visits where gun = bugun and user_id is null),
      'platform', coalesce((select jsonb_object_agg(platform, n) from (
          select platform, count(distinct cihaz_id) n from public.app_visits where gun > bugun - 30 group by platform) x), '{}'::jsonb)
    ),
    'uyeler', jsonb_build_object(
      'toplam',   (select count(*) from gercek_profil),
      'bugun',    (select count(*) from gercek_profil where (created_at at time zone 'Europe/Istanbul')::date = bugun),
      'son7',     (select count(*) from gercek_profil where created_at > now() - interval '7 days'),
      'son30',    (select count(*) from gercek_profil where created_at > now() - interval '30 days'),
      'kayitli_ama_profilsiz', (select count(*) from auth.users u where not public.ornek_hesap(u.id)
                                  and not exists (select 1 from public.profiles p where p.id = u.id)),
      'rol', coalesce((select jsonb_object_agg(role, n) from (select role, count(*) n from gercek_profil group by role) x), '{}'::jsonb)
    ),
    'ilanlar', jsonb_build_object(
      'aktif',       (select count(*) from gercek_ilan where durum = 'aktif' and expires_at > now()),
      'toplam',      (select count(*) from gercek_ilan),
      'bugun',       (select count(*) from gercek_ilan where (created_at at time zone 'Europe/Istanbul')::date = bugun),
      'son7',        (select count(*) from gercek_ilan where created_at > now() - interval '7 days'),
      'satildi',     (select count(*) from gercek_ilan where durum = 'satildi'),
      'pasif',       (select count(*) from gercek_ilan where durum in ('pasif','kaldirildi')),
      'suresi_doldu',(select count(*) from gercek_ilan where durum = 'aktif' and expires_at <= now()),
      'videolu',     (select count(*) from gercek_ilan where durum = 'aktif' and expires_at > now() and video_path is not null),
      'goruntulenme',(select coalesce(sum(goruntulenme), 0) from gercek_ilan),
      'ilan_veren',  (select count(distinct seller_id) from gercek_ilan),
      'ornek_aktif', (select count(*) from public.listings where public.ornek_hesap(seller_id) and durum = 'aktif' and expires_at > now()),
      'tur', coalesce((select jsonb_object_agg(tur, n) from (
          select tur, count(*) n from gercek_ilan where durum = 'aktif' and expires_at > now() group by tur) x), '{}'::jsonb),
      'il', coalesce((select jsonb_agg(jsonb_build_object('il', il, 'n', n) order by n desc) from (
          select il, count(*) n from gercek_ilan where durum = 'aktif' and expires_at > now()
          group by il order by n desc limit 5) x), '[]'::jsonb)
    ),
    'etkilesim', jsonb_build_object(
      'aktif_talep',    (select count(*) from public.wanted_ads where durum = 'aktif' and expires_at > now() and not public.ornek_hesap(buyer_id)),
      'sohbet',         (select count(*) from gercek_sohbet),
      'mesaj',          (select count(*) from gercek_mesaj),
      'mesaj_son7',     (select count(*) from gercek_mesaj where created_at > now() - interval '7 days'),
      'favori',         (select count(*) from public.favorites where not public.ornek_hesap(user_id)),
      'degerlendirme',  (select count(*) from public.reviews where not public.ornek_hesap(reviewer_id)),
      'bekleyen_sikayet',(select count(*) from public.reports where status = 'yeni')
    ),
    'gunluk', (select jsonb_agg(jsonb_build_object(
        'gun', to_char(g, 'YYYY-MM-DD'),
        'cihaz', (select count(*) from public.app_visits v where v.gun = g),
        'uye',   (select count(*) from gercek_profil p where (p.created_at at time zone 'Europe/Istanbul')::date = g),
        'ilan',  (select count(*) from gercek_ilan l where (l.created_at at time zone 'Europe/Istanbul')::date = g)
      ) order by g) from gunler),
    'olusturma', now()
  ) into sonuc;
  return sonuc;
end $$;
revoke all on function public.yonetici_ozet() from public, anon;
grant execute on function public.yonetici_ozet() to authenticated;

-- ============ KENDİNİ YÖNETİCİ YAP ============
-- Aşağıdaki satırdaki numarayı KENDİ telefon numaranla değiştir (başında + olmadan, 90 ile), sonra çalıştır.
-- Uygulamada en az bir kez giriş yapmış olman gerekir. Test numarasını (905559999999) yönetici YAPMA:
-- test kodu herkese açık depoda yazılı, o hesabı herkes açabilir.
-- insert into public.admins (user_id) select id from auth.users where phone = '905XXXXXXXXX' on conflict do nothing;
