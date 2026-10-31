-- Kuzu Deposu: ilana video ekleme. 006'dan sonra çalıştır. Tekrar çalıştırılabilir.
-- İlan başına 1 video (en fazla 50 MB; mp4 / mov / webm).

alter table public.listings add column if not exists video_path text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('listing-videos', 'listing-videos', true, 52428800, array['video/mp4','video/quicktime','video/webm'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists kuzu_video_oku on storage.objects;
drop policy if exists kuzu_video_yukle on storage.objects;
drop policy if exists kuzu_video_guncelle on storage.objects;
drop policy if exists kuzu_video_sil on storage.objects;

create policy kuzu_video_oku on storage.objects for select
  using (bucket_id = 'listing-videos');
create policy kuzu_video_yukle on storage.objects for insert to authenticated
  with check (bucket_id = 'listing-videos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy kuzu_video_guncelle on storage.objects for update to authenticated
  using (bucket_id = 'listing-videos' and (storage.foldername(name))[1] = auth.uid()::text);
create policy kuzu_video_sil on storage.objects for delete to authenticated
  using (bucket_id = 'listing-videos' and (storage.foldername(name))[1] = auth.uid()::text);
