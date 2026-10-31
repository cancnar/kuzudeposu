-- Kuzu Deposu: herkese açık satıcı profili için (002'den sonra çalıştır). Tekrar çalıştırılabilir.
-- 1) Satılan ilanlar başkaları tarafından da görülebilsin (satış geçmişi)
-- 2) Satış tarihi tutulsun

drop policy if exists listings_select on public.listings;
create policy listings_select on public.listings for select
  using ((durum = 'aktif' and expires_at > now()) or durum = 'satildi' or seller_id = auth.uid());

alter table public.listings add column if not exists satildi_at timestamptz;

create or replace function public.satildi_tarihi() returns trigger
language plpgsql as $$
begin
  if new.durum = 'satildi' and (tg_op = 'INSERT' or old.durum is distinct from 'satildi') then
    new.satildi_at := coalesce(new.satildi_at, now());
  elsif new.durum <> 'satildi' then
    new.satildi_at := null;
  end if;
  return new;
end $$;
drop trigger if exists listings_satildi_tarihi on public.listings;
create trigger listings_satildi_tarihi before insert or update of durum on public.listings
  for each row execute function public.satildi_tarihi();

create index if not exists listings_seller_durum on public.listings (seller_id, durum);
