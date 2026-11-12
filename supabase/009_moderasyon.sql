-- Kuzu Deposu: MODERASYON. 008'den sonra çalıştır. Tekrar çalıştırılabilir.
-- Şikâyet kutusu, ilan gizle/yayına al/kaldır, kullanıcı askıya alma, otomatik gizlenenler,
-- şüpheli ilan tespiti, ön onay modu. Tüm yönetici işlemleri yonetici_mi() kontrolünden geçer.
--
-- Güvenlik notları:
--  * profiles ve listings tablolarını kullanıcı kendi satırında güncelleyebiliyor. Bu yüzden
--    askida / moderasyon alanları tetikleyicilerle korunur: yönetici veya güvenilir sistem işlemi
--    (kuzu.guvenilir = 1) dışında kimse değiştiremez.
--  * Yönetici gizlediği veya 3 şikâyetle otomatik gizlenen ilanı satıcı kendisi yeniden yayınlayamaz.

-- ============ YENİ ALANLAR ============
alter table public.profiles add column if not exists askida boolean not null default false;
alter table public.profiles add column if not exists askida_neden text;
alter table public.profiles add column if not exists askida_at timestamptz;

alter table public.listings add column if not exists moderasyon text;
alter table public.listings add column if not exists moderasyon_neden text;
alter table public.listings add column if not exists moderasyon_at timestamptz;
alter table public.listings drop constraint if exists listings_moderasyon_gecerli;
alter table public.listings add constraint listings_moderasyon_gecerli check (moderasyon is null or moderasyon in
  ('onay_bekliyor','otomatik_gizlendi','yonetici_gizledi','yonetici_kaldirdi','hesap_askida'));
create index if not exists listings_moderasyon on public.listings (moderasyon) where moderasyon is not null;
create index if not exists reports_status on public.reports (status, created_at desc);

-- ============ AYARLAR (ön onay modu) ============
create table if not exists public.uygulama_ayarlari (
  anahtar     text primary key,
  deger       jsonb not null,
  guncelleme  timestamptz not null default now()
);
alter table public.uygulama_ayarlari enable row level security;
revoke all on public.uygulama_ayarlari from anon, authenticated;
insert into public.uygulama_ayarlari (anahtar, deger) values ('on_onay', 'false'::jsonb) on conflict do nothing;

create or replace function public.ayar_acik(p_anahtar text) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select deger = 'true'::jsonb from public.uygulama_ayarlari where anahtar = p_anahtar), false);
$$;

-- Yönetici işlemleri ve sistem tetikleyicileri bu bayrağı (sadece o işlem için) açar.
create or replace function public.guvenilir() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(current_setting('kuzu.guvenilir', true), '') = '1' or public.yonetici_mi();
$$;

create or replace function public.askida_mi(p_id uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select askida from public.profiles where id = p_id), false);
$$;

-- ============ KORUMA TETİKLEYİCİLERİ ============
-- Profil: askı alanlarını sadece yönetici değiştirir.
create or replace function public.profil_koru() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if not public.guvenilir() then
    if tg_op = 'INSERT' then
      new.askida := false; new.askida_neden := null; new.askida_at := null;
    else
      new.askida := old.askida; new.askida_neden := old.askida_neden; new.askida_at := old.askida_at;
    end if;
  end if;
  return new;
end $$;
drop trigger if exists profiles_koru on public.profiles;
create trigger profiles_koru before insert or update on public.profiles
  for each row execute function public.profil_koru();

-- İlan eklerken: askıdaki kullanıcı ilan veremez; ön onay açıksa ilan "onay bekliyor" olarak pasif başlar.
create or replace function public.ilan_ekle_kontrol() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if public.askida_mi(new.seller_id) then
    raise exception 'Hesabın askıya alındı; şu an ilan veremezsin.' using errcode = '42501';
  end if;
  if not public.guvenilir() then
    new.moderasyon := null; new.moderasyon_neden := null; new.moderasyon_at := null;
    if public.ayar_acik('on_onay') and new.durum = 'aktif' then
      new.durum := 'pasif';
      new.moderasyon := 'onay_bekliyor';
      new.moderasyon_at := now();
    end if;
  end if;
  return new;
end $$;
drop trigger if exists listings_ekle_kontrol on public.listings;
create trigger listings_ekle_kontrol before insert on public.listings
  for each row execute function public.ilan_ekle_kontrol();

-- İlan güncellerken: moderasyon alanları korunur; incelemedeki ilan satıcı tarafından yayına alınamaz.
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
  return new;
end $$;
drop trigger if exists listings_guncelle_kontrol on public.listings;
create trigger listings_guncelle_kontrol before update on public.listings
  for each row execute function public.ilan_guncelle_kontrol();

-- Askıdaki kullanıcı mesaj, sohbet, talep ve yorum oluşturamaz. Argüman: kişiyi tutan sütun adı.
create or replace function public.askida_engelle() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if public.askida_mi((to_jsonb(new) ->> tg_argv[0])::uuid) then
    raise exception 'Hesabın askıya alındı; bu işlemi yapamazsın.' using errcode = '42501';
  end if;
  return new;
end $$;
drop trigger if exists messages_askida on public.messages;
create trigger messages_askida before insert on public.messages for each row execute function public.askida_engelle('sender_id');
drop trigger if exists conversations_askida on public.conversations;
create trigger conversations_askida before insert on public.conversations for each row execute function public.askida_engelle('buyer_id');
drop trigger if exists wanted_askida on public.wanted_ads;
create trigger wanted_askida before insert on public.wanted_ads for each row execute function public.askida_engelle('buyer_id');
drop trigger if exists reviews_askida on public.reviews;
create trigger reviews_askida before insert on public.reviews for each row execute function public.askida_engelle('reviewer_id');

-- Onaylanan ilan için "aramana uyan yeni ilan" bildirimleri şimdi gönderilir (eklenirken pasifti).
drop trigger if exists listings_onay_bildirim on public.listings;
create trigger listings_onay_bildirim after update on public.listings
  for each row when (old.moderasyon = 'onay_bekliyor' and new.moderasyon is null and new.durum = 'aktif')
  execute function public.bildirim_yeni_ilan();

-- ============ 005'İN YENİ HALİ: otomatik gizleme moderasyon kuyruğuna düşer ============
create or replace function public.sikayet_otomatik_gizle() returns trigger
language plpgsql security definer set search_path = public as $$
declare n int; l public.listings;
begin
  if new.listing_id is null or new.reason not in ('baska_hayvan_fotografi','sahte_ilan','kapora_istiyor') then
    return null;
  end if;
  select count(distinct reporter_id) into n from public.reports
   where listing_id = new.listing_id and reason in ('baska_hayvan_fotografi','sahte_ilan','kapora_istiyor')
     and status <> 'kapandi';
  if n >= 3 then
    perform set_config('kuzu.guvenilir', '1', true);
    update public.listings
       set durum = 'pasif', moderasyon = 'otomatik_gizlendi',
           moderasyon_neden = n || ' farklı kişiden şikâyet', moderasyon_at = now()
     where id = new.listing_id and durum = 'aktif' returning * into l;
    perform set_config('kuzu.guvenilir', '', true);
    if l.id is not null then
      insert into public.notifications (user_id, type, title, body, data)
      values (l.seller_id, 'sikayet', 'İlanın yayından kaldırıldı',
              l.cins || ' ilanın birden fazla şikâyet aldığı için incelemeye alındı.',
              jsonb_build_object('listing_id', l.id));
    end if;
  end if;
  return null;
end $$;

-- Daha önce otomatik gizlenmiş ilanları kuyruğa al (geriye dönük).
do $$ begin
  perform set_config('kuzu.guvenilir', '1', true);
  update public.listings l set moderasyon = 'otomatik_gizlendi', moderasyon_neden = 'Şikâyetle otomatik gizlendi', moderasyon_at = now()
   where l.durum = 'pasif' and l.moderasyon is null
     and (select count(distinct r.reporter_id) from public.reports r
           where r.listing_id = l.id and r.reason in ('baska_hayvan_fotografi','sahte_ilan','kapora_istiyor')) >= 3;
  perform set_config('kuzu.guvenilir', '', true);
end $$;

-- ============ ŞÜPHELİ İLAN TESPİTİ ============
-- Açıklamadaki IBAN, telefon numarası ve kapora/ön ödeme ifadeleri. (Fotoğraftaki yazı okunamaz.)
create or replace function public.metin_supheli(p text) returns text[]
language plpgsql immutable as $$
declare n text[] := '{}'; t text := lower(coalesce(p, ''));
begin
  if t ~ 'tr\s*\d{2}(\s*\d){20,24}' or t ~ '\miban\M' then n := array_append(n, 'IBAN'); end if;
  if regexp_replace(t, 'tr\s*\d{2}(\s*\d){20,24}', '', 'g') ~ '(\+?\s*90|0)?[\s(]*5\d{2}[\s).-]*\d{3}[\s.-]*\d{2}[\s.-]*\d{2}' then n := array_append(n, 'Telefon numarası'); end if;
  if t ~ '(kapora|kaparo|ön ?ödeme|on ?odeme|peşin ödeme|pesin odeme|havale|\meft\M|kargo ?ücreti)' then n := array_append(n, 'Kapora / ön ödeme'); end if;
  return n;
end $$;

-- Bir ilanın şüphe nedenleri: metin + aynı türün aktif ilan medyanının yarısından ucuz kg fiyatı.
create or replace function public.ilan_supheli(l public.listings) returns text[]
language plpgsql stable security definer set search_path = public as $$
declare n text[] := public.metin_supheli(l.aciklama); med numeric; adet int;
begin
  select percentile_cont(0.5) within group (order by kg_fiyat), count(*) into med, adet
    from public.listings where tur = l.tur and durum = 'aktif' and expires_at > now() and id <> l.id;
  if adet >= 3 and med > 0 and l.kg_fiyat < med * 0.5 then n := array_append(n, 'Piyasanın yarısından ucuz'); end if;
  return n;
end $$;

-- ============ YÖNETİCİ: YARDIMCI ============
create or replace function public.yonetici_kontrol() returns void
language plpgsql stable security definer set search_path = public as $$
begin
  if not public.yonetici_mi() then
    raise exception 'yetki yok: bu işlem sadece yöneticiye açık' using errcode = '42501';
  end if;
end $$;

-- Paneldeki ilan satırı (ilan + satıcı + ilk fotoğraf + şüphe + şikâyet sayısı)
create or replace function public.yonetici_ilan_json(l public.listings) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'ilan', to_jsonb(l),
    'satici', (select jsonb_build_object('id', p.id, 'ad', p.full_name, 'askida', p.askida) from public.profiles p where p.id = l.seller_id),
    'foto', (select path from public.listing_photos f where f.listing_id = l.id order by sort_order limit 1),
    'nedenler', to_jsonb(public.ilan_supheli(l)),
    'sikayet', (select count(*) from public.reports r where r.listing_id = l.id and r.status <> 'kapandi')
  );
$$;

-- ============ YÖNETİCİ: MODERASYON ÖZETİ ============
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
    'on_onay',           public.ayar_acik('on_onay')
  );
end $$;

-- ============ YÖNETİCİ: ŞİKÂYETLER ============
create or replace function public.yonetici_sikayetler(p_durum text default 'yeni') returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform public.yonetici_kontrol();
  return coalesce((select jsonb_agg(x order by (x->>'created_at') desc) from (
    select jsonb_build_object(
      'id', r.id, 'reason', r.reason, 'detail', r.detail, 'status', r.status, 'created_at', r.created_at,
      'bildiren', (select jsonb_build_object('id', p.id, 'ad', p.full_name) from public.profiles p where p.id = r.reporter_id),
      'ilan', (select public.yonetici_ilan_json(l) from public.listings l where l.id = r.listing_id),
      'kullanici', (select jsonb_build_object('id', p.id, 'ad', p.full_name, 'askida', p.askida) from public.profiles p where p.id = r.reported_user_id),
      'ayni_ilan', (select count(distinct r2.reporter_id) from public.reports r2 where r.listing_id is not null and r2.listing_id = r.listing_id)
    ) x
    from public.reports r where r.status = p_durum order by r.created_at desc limit 100) t), '[]'::jsonb);
end $$;

create or replace function public.yonetici_sikayet_durum(p_id uuid, p_durum text) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public.yonetici_kontrol();
  if p_durum not in ('yeni','inceleniyor','kapandi') then raise exception 'geçersiz durum'; end if;
  update public.reports set status = p_durum where id = p_id;
end $$;

-- ============ YÖNETİCİ: İLANLAR ============
-- p_filtre: onay | otomatik | gizli | supheli | satici (p_satici ile) | tumu (p_ara ile arama)
create or replace function public.yonetici_ilanlar(p_filtre text, p_ara text default null, p_satici uuid default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare q text := nullif(trim(coalesce(p_ara, '')), '');
begin
  perform public.yonetici_kontrol();
  return coalesce((select jsonb_agg(public.yonetici_ilan_json(l) order by l.created_at desc) from (
    select l.* from public.listings l
    where case p_filtre
      when 'onay'     then l.moderasyon = 'onay_bekliyor'
      when 'otomatik' then l.moderasyon = 'otomatik_gizlendi'
      when 'gizli'    then l.moderasyon in ('yonetici_gizledi','yonetici_kaldirdi','hesap_askida')
      when 'supheli'  then (l.durum = 'aktif' and l.expires_at > now() or l.moderasyon = 'onay_bekliyor')
                           and cardinality(public.ilan_supheli(l)) > 0
      when 'satici'   then l.seller_id = p_satici
      else q is null or l.cins ilike '%' || q || '%' or l.il ilike '%' || q || '%' or l.ilce ilike '%' || q || '%'
           or coalesce(l.aciklama, '') ilike '%' || q || '%'
           or exists (select 1 from public.profiles p where p.id = l.seller_id and p.full_name ilike '%' || q || '%')
    end
    order by l.created_at desc limit 100) l), '[]'::jsonb);
end $$;

-- p_islem: onayla | yayina_al | gizle | kaldir. İlana bağlı açık şikâyetler kapanır, satıcıya bildirim gider.
create or replace function public.yonetici_ilan_islem(p_id uuid, p_islem text, p_neden text default null) returns void
language plpgsql security definer set search_path = public as $$
declare l public.listings; baslik text; govde text;
begin
  perform public.yonetici_kontrol();
  select * into l from public.listings where id = p_id;
  if l.id is null then raise exception 'ilan bulunamadı'; end if;
  perform set_config('kuzu.guvenilir', '1', true);
  if p_islem in ('onayla', 'yayina_al') then
    if public.askida_mi(l.seller_id) then raise exception 'Satıcının hesabı askıda; önce askıyı kaldır.'; end if;
    update public.listings set durum = 'aktif', moderasyon = null, moderasyon_neden = null, moderasyon_at = now(),
           expires_at = greatest(expires_at, now() + interval '7 days')
     where id = p_id;
    baslik := case when p_islem = 'onayla' then 'İlanın onaylandı' else 'İlanın tekrar yayında' end;
    govde := l.cins || ' ilanın yayında.';
  elsif p_islem = 'gizle' then
    update public.listings set durum = 'pasif', moderasyon = 'yonetici_gizledi', moderasyon_neden = p_neden, moderasyon_at = now() where id = p_id;
    baslik := 'İlanın yayından kaldırıldı';
    govde := l.cins || ' ilanın yönetici tarafından gizlendi' || coalesce(': ' || p_neden, '.');
  elsif p_islem = 'kaldir' then
    update public.listings set durum = 'kaldirildi', moderasyon = 'yonetici_kaldirdi', moderasyon_neden = p_neden, moderasyon_at = now() where id = p_id;
    baslik := case when l.moderasyon = 'onay_bekliyor' then 'İlanın onaylanmadı' else 'İlanın kaldırıldı' end;
    govde := l.cins || ' ilanın yayınlanmayacak' || coalesce(': ' || p_neden, '.');
  else
    raise exception 'geçersiz işlem: %', p_islem;
  end if;
  perform set_config('kuzu.guvenilir', '', true);
  update public.reports set status = 'kapandi' where listing_id = p_id and status <> 'kapandi';
  insert into public.notifications (user_id, type, title, body, data)
  values (l.seller_id, 'moderasyon', baslik, govde, jsonb_build_object('listing_id', l.id));
end $$;

-- ============ YÖNETİCİ: KULLANICILAR ============
create or replace function public.yonetici_kullanici_json(p public.profiles) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', p.id, 'ad', p.full_name, 'il', p.il, 'ilce', p.ilce, 'rol', p.role, 'created_at', p.created_at,
    'askida', p.askida, 'askida_neden', p.askida_neden, 'askida_at', p.askida_at,
    'telefon', (select u.phone from auth.users u where u.id = p.id),
    'yonetici', exists (select 1 from public.admins a where a.user_id = p.id),
    'ornek', public.ornek_hesap(p.id),
    'ilan_aktif', (select count(*) from public.listings l where l.seller_id = p.id and l.durum = 'aktif' and l.expires_at > now()),
    'ilan_toplam', (select count(*) from public.listings l where l.seller_id = p.id),
    'satildi', (select count(*) from public.listings l where l.seller_id = p.id and l.durum = 'satildi'),
    'mesaj', (select count(*) from public.messages m where m.sender_id = p.id),
    'talep', (select count(*) from public.wanted_ads w where w.buyer_id = p.id),
    'puan', p.rating_avg, 'puan_sayisi', p.rating_count,
    'sikayet', (select count(*) from public.reports r left join public.listings l on l.id = r.listing_id
                 where r.status <> 'kapandi' and (r.reported_user_id = p.id or l.seller_id = p.id)),
    'sikayet_toplam', (select count(*) from public.reports r left join public.listings l on l.id = r.listing_id
                 where r.reported_user_id = p.id or l.seller_id = p.id)
  );
$$;

create or replace function public.yonetici_kullanicilar(p_ara text default null, p_sadece_askida boolean default false) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare q text := nullif(trim(coalesce(p_ara, '')), ''); rakam text := regexp_replace(coalesce(p_ara, ''), '\D', '', 'g');
begin
  perform public.yonetici_kontrol();
  if length(rakam) > 0 and rakam ~ '^0' then rakam := '9' || rakam; end if;
  return coalesce((select jsonb_agg(public.yonetici_kullanici_json(p) order by p.created_at desc) from (
    select p.* from public.profiles p
    where (not p_sadece_askida or p.askida)
      and (q is null
           or p.full_name ilike '%' || q || '%'
           or (length(rakam) >= 4 and exists (select 1 from auth.users u where u.id = p.id and u.phone like '%' || rakam || '%')))
    order by p.created_at desc limit 50) p), '[]'::jsonb);
end $$;

-- Tek kullanıcı: bilgiler + hakkındaki şikâyetler + ilanları
create or replace function public.yonetici_kullanici(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare p public.profiles;
begin
  perform public.yonetici_kontrol();
  select * into p from public.profiles where id = p_id;
  if p.id is null then raise exception 'kullanıcı bulunamadı'; end if;
  return public.yonetici_kullanici_json(p) || jsonb_build_object(
    'sikayetler', coalesce((select jsonb_agg(jsonb_build_object(
        'id', r.id, 'reason', r.reason, 'detail', r.detail, 'status', r.status, 'created_at', r.created_at,
        'ilan', l.cins, 'bildiren', (select full_name from public.profiles b where b.id = r.reporter_id))
        order by r.created_at desc)
      from public.reports r left join public.listings l on l.id = r.listing_id
      where r.reported_user_id = p_id or l.seller_id = p_id), '[]'::jsonb),
    'ilanlar', public.yonetici_ilanlar('satici', null, p_id)
  );
end $$;

-- Askıya alma: aktif ilanlar gizlenir (hesap_askida); askı kalkınca bu ilanlar geri açılır.
create or replace function public.yonetici_askiya_al(p_id uuid, p_askida boolean, p_neden text default null) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public.yonetici_kontrol();
  if p_id = auth.uid() then raise exception 'Kendi hesabını askıya alamazsın.'; end if;
  if p_askida and exists (select 1 from public.admins where user_id = p_id) then
    raise exception 'Bir yönetici askıya alınamaz.';
  end if;
  perform set_config('kuzu.guvenilir', '1', true);
  update public.profiles set askida = p_askida,
         askida_neden = case when p_askida then p_neden end,
         askida_at = case when p_askida then now() end
   where id = p_id;
  if p_askida then
    update public.listings set durum = 'pasif', moderasyon = 'hesap_askida', moderasyon_neden = p_neden, moderasyon_at = now()
     where seller_id = p_id and durum = 'aktif';
    update public.wanted_ads set durum = 'kapandi' where buyer_id = p_id and durum = 'aktif';
  else
    update public.listings set durum = 'aktif', moderasyon = null, moderasyon_neden = null, moderasyon_at = now()
     where seller_id = p_id and moderasyon = 'hesap_askida';
  end if;
  perform set_config('kuzu.guvenilir', '', true);
  insert into public.notifications (user_id, type, title, body, data)
  values (p_id, 'moderasyon',
          case when p_askida then 'Hesabın askıya alındı' else 'Hesabın tekrar açıldı' end,
          case when p_askida then coalesce(p_neden, 'Kurallara aykırı kullanım.') || ' İtiraz için destekle iletişime geç.'
               else 'İlanların yeniden yayında.' end,
          '{}'::jsonb);
end $$;

-- ============ YÖNETİCİ: AYARLAR ============
create or replace function public.yonetici_ayar(p_anahtar text, p_deger jsonb) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform public.yonetici_kontrol();
  if p_anahtar not in ('on_onay') then raise exception 'bilinmeyen ayar: %', p_anahtar; end if;
  insert into public.uygulama_ayarlari (anahtar, deger, guncelleme) values (p_anahtar, p_deger, now())
  on conflict (anahtar) do update set deger = excluded.deger, guncelleme = now();
end $$;

-- ============ YETKİLER ============
-- Yardımcılar uygulamadan doğrudan çağrılamaz; yönetici fonksiyonları içeride yonetici_kontrol() yapar.
revoke all on function public.ayar_acik(text), public.guvenilir(), public.askida_mi(uuid),
  public.ilan_supheli(public.listings), public.yonetici_ilan_json(public.listings),
  public.yonetici_kullanici_json(public.profiles) from public, anon, authenticated;
revoke all on function public.yonetici_moderasyon_ozet(), public.yonetici_sikayetler(text), public.yonetici_sikayet_durum(uuid, text),
  public.yonetici_ilanlar(text, text, uuid), public.yonetici_ilan_islem(uuid, text, text),
  public.yonetici_kullanicilar(text, boolean), public.yonetici_kullanici(uuid),
  public.yonetici_askiya_al(uuid, boolean, text), public.yonetici_ayar(text, jsonb) from public, anon;
grant execute on function public.yonetici_moderasyon_ozet(), public.yonetici_sikayetler(text), public.yonetici_sikayet_durum(uuid, text),
  public.yonetici_ilanlar(text, text, uuid), public.yonetici_ilan_islem(uuid, text, text),
  public.yonetici_kullanicilar(text, boolean), public.yonetici_kullanici(uuid),
  public.yonetici_askiya_al(uuid, boolean, text), public.yonetici_ayar(text, jsonb) to authenticated;
