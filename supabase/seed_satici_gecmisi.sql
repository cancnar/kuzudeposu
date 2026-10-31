-- ÖRNEK satış geçmişi ve yorumlar (sadece test için). 003_satici_profili.sql'den SONRA, bir kez çalıştır.
-- Örnek satıcılara (seed_ornek_ilanlar.sql) satılmış ilanlar ve gerçek yorum kayıtları ekler.
-- Satıcı puanları artık bu yorumlardan otomatik hesaplanır.
-- Temizlemek için: delete from auth.users where id::text like 'aaaaaaaa-0000-0000-0000-00000000000%' or id::text like 'cccccccc-0000-0000-0000-00000000000%';

do $$
declare
  s uuid[] := array['aaaaaaaa-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000002','aaaaaaaa-0000-0000-0000-000000000003',
                    'aaaaaaaa-0000-0000-0000-000000000004','aaaaaaaa-0000-0000-0000-000000000005','aaaaaaaa-0000-0000-0000-000000000006']::uuid[];
  b uuid[] := array['cccccccc-0000-0000-0000-000000000001','cccccccc-0000-0000-0000-000000000002','cccccccc-0000-0000-0000-000000000003',
                    'cccccccc-0000-0000-0000-000000000004','cccccccc-0000-0000-0000-000000000005','cccccccc-0000-0000-0000-000000000006']::uuid[];
  bn text[] := array['Ayşe Demir (örnek)','Hasan Tekin (örnek)','Zeynep Arslan (örnek)','Mustafa Koç (örnek)','Emine Yılmaz (örnek)','İbrahim Öztürk (örnek)'];
  yorum text[] := array[
    '[Örnek yorum] Hayvanlar ilanda yazdığı gibi çıktı, teslimat zamanında oldu.',
    '[Örnek yorum] Güvenilir satıcı, pazarlıkta anlayışlı davrandı.',
    '[Örnek yorum] Ortalama ağırlık biraz düşük çıktı ama genel olarak memnun kaldım.',
    '[Örnek yorum] Hızlı dönüş yaptı, hayvanları yerinde gördük, sorunsuz alışveriş.',
    '[Örnek yorum] Fotoğraflar gerçeği yansıtıyordu. Tavsiye ederim.',
    '[Örnek yorum] Biraz geç cevap verdi ama sonuçta anlaştık.'];
  puan int[][] := array[[5,5,4,5,5,4],[4,5,4,4,5,3],[5,5,5,5,4,5],[4,4,5,3,4,4],[5,5,5,5,5,5],[5,4,5,4,4,5]];
  i int; j int; lid uuid; cid uuid; ilan_say int;
begin
  for j in 1..6 loop
    insert into auth.users (id, instance_id, aud, role, phone, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
    values (b[j], '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', '9055510000' || lpad(j::text, 2, '0'), now(), now(), '{}'::jsonb, '{}'::jsonb)
    on conflict (id) do nothing;
    insert into public.profiles (id, full_name, il, ilce, role) values (b[j], bn[j], 'Ankara', 'Çankaya', 'alici') on conflict (id) do nothing;
  end loop;

  for i in 1..6 loop
    -- satılmış ilanlar (her satıcıya 2-4 adet)
    insert into public.listings (seller_id, tur, cins, cinsiyet, adet, yas_min, yas_max, agirlik_kg, toplam_fiyat, satis_sekli, aciklama, il, ilce, durum, created_at, satildi_at)
    select s[i], v.tur, v.cins, v.cinsiyet, v.adet, v.y1, v.y2, v.kg, v.fiyat, 'birlikte', '[ÖRNEK İLAN] Satıldı.', p.il, p.ilce, 'satildi',
           now() - (v.gun + 20 || ' days')::interval, now() - (v.gun || ' days')::interval
    from public.profiles p,
    (values
      ('kucukbas','Akkaraman','karisik',30,10,14,58,680000,12),
      ('buyukbas','Simental','disi',1,26,26,540,225000,35),
      ('kucukbas','Kıvırcık','erkek',15,8,10,47,285000,60),
      ('buyukbas','Holstein','disi',2,30,36,590,430000,90)
    ) as v(tur,cins,cinsiyet,adet,y1,y2,kg,fiyat,gun)
    where p.id = s[i] and (v.gun < 40 or i <= 4);

    -- yorumlar: her alıcı, satıcının bir ilanında konuşup yorum bırakır
    select id into lid from public.listings where seller_id = s[i] order by created_at limit 1;
    for j in 1..6 loop
      insert into public.conversations (listing_id, buyer_id, seller_id) values (lid, b[j], s[i]) on conflict (listing_id, buyer_id) do nothing;
      select id into cid from public.conversations where listing_id = lid and buyer_id = b[j];
      insert into public.messages (conversation_id, sender_id, body, created_at)
      select cid, b[j], 'Merhaba, ilanla ilgileniyorum.', now() - (j * 11 || ' days')::interval
      where not exists (select 1 from public.messages where conversation_id = cid);
      insert into public.reviews (conversation_id, reviewer_id, seller_id, rating, comment, created_at)
      values (cid, b[j], s[i], puan[i][j], yorum[((i + j) % 6) + 1], now() - (j * 9 + i || ' days')::interval)
      on conflict (conversation_id, reviewer_id) do nothing;
    end loop;
  end loop;
end $$;

select p.full_name, p.rating_avg, p.rating_count,
  (select count(*) from public.listings l where l.seller_id = p.id and l.durum = 'satildi') as satilan
from public.profiles p where p.id::text like 'aaaaaaaa-%' order by p.id;
