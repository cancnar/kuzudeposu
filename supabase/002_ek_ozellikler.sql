-- Kuzu Deposu: ek özellikler (schema.sql'den SONRA çalıştır). Tekrar çalıştırılabilir.
-- 1) Fotoğraf kovaları ve yükleme izinleri
-- 2) Gerçek zamanlı mesajlaşma
-- 3) Otomatik bildirimler (mesaj, yorum, fiyat düşüşü, kayıtlı aramaya uyan ilan)
-- 4) Hesap silme fonksiyonu

-- ===== 1) Storage =====
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('listing-photos', 'listing-photos', true, 5242880, array['image/jpeg','image/png','image/webp']),
  ('avatars',        'avatars',        true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists kuzu_foto_oku on storage.objects;
drop policy if exists kuzu_foto_yukle on storage.objects;
drop policy if exists kuzu_foto_guncelle on storage.objects;
drop policy if exists kuzu_foto_sil on storage.objects;

create policy kuzu_foto_oku on storage.objects for select
  using (bucket_id in ('listing-photos','avatars'));
create policy kuzu_foto_yukle on storage.objects for insert to authenticated
  with check (bucket_id in ('listing-photos','avatars') and (storage.foldername(name))[1] = auth.uid()::text);
create policy kuzu_foto_guncelle on storage.objects for update to authenticated
  using (bucket_id in ('listing-photos','avatars') and (storage.foldername(name))[1] = auth.uid()::text);
create policy kuzu_foto_sil on storage.objects for delete to authenticated
  using (bucket_id in ('listing-photos','avatars') and (storage.foldername(name))[1] = auth.uid()::text);

-- ===== 2) Gerçek zamanlı =====
do $$
begin
  begin alter publication supabase_realtime add table public.messages; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.notifications; exception when duplicate_object then null; end;
end $$;

-- ===== 3) Otomatik bildirimler =====
create or replace function public.bildirim_mesaj() returns trigger
language plpgsql security definer set search_path = public as $$
declare c public.conversations; alici uuid; gonderen text;
begin
  select * into c from public.conversations where id = new.conversation_id;
  alici := case when new.sender_id = c.buyer_id then c.seller_id else c.buyer_id end;
  select full_name into gonderen from public.profiles where id = new.sender_id;
  insert into public.notifications (user_id, type, title, body, data)
  values (alici, 'mesaj', coalesce(gonderen, 'Biri') || ' sana mesaj gönderdi', left(new.body, 120),
          jsonb_build_object('conversation_id', c.id));
  return null;
end $$;
drop trigger if exists messages_bildirim on public.messages;
create trigger messages_bildirim after insert on public.messages
  for each row execute function public.bildirim_mesaj();

create or replace function public.bildirim_yorum() returns trigger
language plpgsql security definer set search_path = public as $$
declare yazan text;
begin
  select full_name into yazan from public.profiles where id = new.reviewer_id;
  insert into public.notifications (user_id, type, title, body, data)
  values (new.seller_id, 'yorum', 'Yeni yorum aldın',
          coalesce(yazan, 'Bir alıcı') || ' sana ' || new.rating || ' yıldız verdi.',
          jsonb_build_object('seller_id', new.seller_id));
  return null;
end $$;
drop trigger if exists reviews_bildirim on public.reviews;
create trigger reviews_bildirim after insert on public.reviews
  for each row execute function public.bildirim_yorum();

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
    and (coalesce(s.filters->>'cins','') = '' or new.cins ilike '%' || (s.filters->>'cins') || '%')
    and (coalesce(s.filters->>'il','') = '' or (new.il || ' ' || new.ilce) ilike '%' || (s.filters->>'il') || '%');
  return null;
end $$;
drop trigger if exists listings_yeni_bildirim on public.listings;
create trigger listings_yeni_bildirim after insert on public.listings
  for each row when (new.durum = 'aktif') execute function public.bildirim_yeni_ilan();

create or replace function public.bildirim_fiyat() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.toplam_fiyat < old.toplam_fiyat then
    insert into public.notifications (user_id, type, title, body, data)
    select f.user_id, 'fiyat', 'Favori ilanın fiyatı düştü',
           new.cins || ': ' || to_char(old.toplam_fiyat, 'FM999G999G999') || ' ₺ → ' || to_char(new.toplam_fiyat, 'FM999G999G999') || ' ₺',
           jsonb_build_object('listing_id', new.id)
    from public.favorites f where f.listing_id = new.id and f.user_id <> new.seller_id;
  end if;
  return null;
end $$;
drop trigger if exists listings_fiyat_bildirim on public.listings;
create trigger listings_fiyat_bildirim after update of toplam_fiyat on public.listings
  for each row execute function public.bildirim_fiyat();

-- ===== 4) Hesap silme (Apple/Google zorunluluğu) =====
create or replace function public.hesabimi_sil() returns void
language plpgsql security definer set search_path = public, auth as $$
begin
  if auth.uid() is null then raise exception 'Giriş gerekli'; end if;
  delete from auth.users where id = auth.uid();   -- profil, ilan, mesaj, yorum zincirleme silinir
end $$;
revoke all on function public.hesabimi_sil() from public, anon;
grant execute on function public.hesabimi_sil() to authenticated;
