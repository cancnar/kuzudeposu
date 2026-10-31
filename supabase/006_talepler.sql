-- Kuzu Deposu: ALICI TALEPLERİ ("şunu arıyorum" ilanları). 005'ten sonra çalıştır. Tekrar çalıştırılabilir.
-- Alıcı ne aradığını yayınlar; eşleşen ilanı olan satıcılara bildirim gider; satıcı kendi ilanını talebe önerir ve sohbet açılır.

create table if not exists public.wanted_ads (
  id          uuid primary key default gen_random_uuid(),
  buyer_id    uuid not null references public.profiles(id) on delete cascade,
  tur         text not null check (tur in ('buyukbas','kucukbas','kanatli','at')),
  cins        text,
  adet        int not null default 1 check (adet between 1 and 1000),
  amac        text check (amac is null or amac in ('kurbanlik','besi','damizlik','sut_yumurta','kesim','diger')),
  butce_max   numeric(12,2) check (butce_max is null or butce_max > 0),
  il          text not null,
  aciklama    text check (aciklama is null or char_length(aciklama) <= 1000),
  durum       text not null default 'aktif' check (durum in ('aktif','kapandi')),
  created_at  timestamptz not null default now(),
  expires_at  timestamptz not null default now() + interval '30 days'
);
create index if not exists wanted_durum_created on public.wanted_ads (durum, created_at desc);
create index if not exists wanted_buyer on public.wanted_ads (buyer_id);

alter table public.wanted_ads enable row level security;
drop policy if exists wanted_select on public.wanted_ads;
create policy wanted_select on public.wanted_ads for select
  using ((durum = 'aktif' and expires_at > now()) or buyer_id = auth.uid());
drop policy if exists wanted_insert on public.wanted_ads;
create policy wanted_insert on public.wanted_ads for insert to authenticated with check (buyer_id = auth.uid());
drop policy if exists wanted_update on public.wanted_ads;
create policy wanted_update on public.wanted_ads for update to authenticated
  using (buyer_id = auth.uid()) with check (buyer_id = auth.uid());
drop policy if exists wanted_delete on public.wanted_ads;
create policy wanted_delete on public.wanted_ads for delete to authenticated using (buyer_id = auth.uid());
grant select on public.wanted_ads to anon, authenticated;

-- Yeni talepte: aynı türde (ve cins belirtildiyse aynı cinste) aktif ilanı olan satıcılara bildirim
create or replace function public.bildirim_yeni_talep() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.notifications (user_id, type, title, body, data)
  select distinct l.seller_id, 'talep', 'Senin ilanına uygun bir talep var',
         coalesce(new.cins, 'Hayvan') || ' arıyor · ' || new.il,
         jsonb_build_object('wanted_id', new.id)
  from public.listings l
  where l.durum = 'aktif' and l.expires_at > now() and l.tur = new.tur
    and (new.cins is null or l.cins ilike new.cins)
    and l.seller_id <> new.buyer_id
  limit 200;
  return null;
end $$;
drop trigger if exists wanted_bildirim on public.wanted_ads;
create trigger wanted_bildirim after insert on public.wanted_ads
  for each row execute function public.bildirim_yeni_talep();

-- Satıcı kendi ilanını talebe önerir: alıcı ile satıcı arasında sohbet açar, ilk mesajı gönderir.
create or replace function public.talebe_ilan_oner(p_talep uuid, p_ilan uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare w public.wanted_ads; l public.listings; k uuid;
begin
  if auth.uid() is null then raise exception 'Giriş gerekli'; end if;
  select * into w from public.wanted_ads where id = p_talep and durum = 'aktif' and expires_at > now();
  if w.id is null then raise exception 'Talep bulunamadı veya kapandı'; end if;
  select * into l from public.listings where id = p_ilan and seller_id = auth.uid() and durum = 'aktif';
  if l.id is null then raise exception 'Önerilecek aktif bir ilanın olmalı'; end if;
  if w.buyer_id = auth.uid() then raise exception 'Kendi talebine öneri yapamazsın'; end if;
  if exists (select 1 from public.blocks b
             where (b.blocker_id = w.buyer_id and b.blocked_id = auth.uid())
                or (b.blocker_id = auth.uid() and b.blocked_id = w.buyer_id)) then
    raise exception 'Bu kullanıcıyla iletişim kurulamaz';
  end if;
  insert into public.conversations (listing_id, buyer_id, seller_id)
  values (l.id, w.buyer_id, auth.uid())
  on conflict (listing_id, buyer_id) do nothing;
  select id into k from public.conversations where listing_id = l.id and buyer_id = w.buyer_id;
  insert into public.messages (conversation_id, sender_id, body)
  values (k, auth.uid(), 'Merhaba, talebin için ilanım var: ' || l.cins || ' · ' || l.adet || ' baş · ' ||
          to_char(l.toplam_fiyat, 'FM999G999G999') || ' ₺. Detaylar ilanda, sorularını yazabilirsin.');
  return k;
end $$;
revoke all on function public.talebe_ilan_oner(uuid, uuid) from public, anon;
grant execute on function public.talebe_ilan_oner(uuid, uuid) to authenticated;
