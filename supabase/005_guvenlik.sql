-- Kuzu Deposu: otomatik güvenlik. 004'ten sonra çalıştır. Tekrar çalıştırılabilir.
-- Bir ilan, 3 farklı kişiden dolandırıcılık türü şikayet alırsa otomatik yayından kalkar ve satıcıya bildirim gider.
create or replace function public.sikayet_otomatik_gizle() returns trigger
language plpgsql security definer set search_path = public as $$
declare n int; l public.listings;
begin
  if new.listing_id is null or new.reason not in ('baska_hayvan_fotografi','sahte_ilan','kapora_istiyor') then
    return null;
  end if;
  select count(distinct reporter_id) into n from public.reports
   where listing_id = new.listing_id and reason in ('baska_hayvan_fotografi','sahte_ilan','kapora_istiyor');
  if n >= 3 then
    update public.listings set durum = 'pasif' where id = new.listing_id and durum = 'aktif' returning * into l;
    if l.id is not null then
      insert into public.notifications (user_id, type, title, body, data)
      values (l.seller_id, 'sikayet', 'İlanın yayından kaldırıldı',
              l.cins || ' ilanın birden fazla şikayet aldığı için incelemeye alındı.',
              jsonb_build_object('listing_id', l.id));
    end if;
  end if;
  return null;
end $$;
drop trigger if exists reports_otomatik_gizle on public.reports;
create trigger reports_otomatik_gizle after insert on public.reports
  for each row execute function public.sikayet_otomatik_gizle();
