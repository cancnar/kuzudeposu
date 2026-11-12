-- Kuzu Deposu: ÖRNEK İLANLAR (sadece test içindir)
-- Supabase > SQL Editor'de çalıştır. Önce schema.sql çalışmış olmalı.
-- Fiyatlar 2026 canlı kg fiyatlarına yakın seçildi (büyükbaş ~411 TL/kg, küçükbaş ~398 TL/kg; Türkiye Ziraat Odaları Birliği verisi).
-- Satıcılar "(örnek)" etiketli sahte hesaplardır; bu numaralarla giriş yapılamaz.
-- Temizlemek için dosyanın en altındaki silme komutunu çalıştır.

do $$
declare
  s uuid[] := array[
    'aaaaaaaa-0000-0000-0000-000000000001','aaaaaaaa-0000-0000-0000-000000000002',
    'aaaaaaaa-0000-0000-0000-000000000003','aaaaaaaa-0000-0000-0000-000000000004',
    'aaaaaaaa-0000-0000-0000-000000000005','aaaaaaaa-0000-0000-0000-000000000006']::uuid[];
  n text[] := array['Mehmet Kaya (örnek)','Hatice Demir (örnek)','Ali Rıza Çelik (örnek)',
                    'Süleyman Aydın (örnek)','Fatma Yıldız (örnek)','Hasan Şahin (örnek)'];
  il text[] := array['Manisa','Konya','Balıkesir','Aksaray','İzmir','Edirne'];
  ilce text[] := array['Salihli','Karatay','Bandırma','Eskil','Çeşme','Keşan'];
  r text[] := array['yetistirici','tuccar','yetistirici','tuccar','yetistirici','yetistirici'];
  i int;
begin
  for i in 1..6 loop
    insert into auth.users (id, instance_id, aud, role, phone, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
    values (s[i], '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
            '9055500000' || lpad(i::text, 2, '0'), now(), now(), '{}'::jsonb, '{}'::jsonb)
    on conflict (id) do nothing;
    insert into public.profiles (id, full_name, il, ilce, role, rating_avg, rating_count)
    values (s[i], n[i], il[i], ilce[i], r[i],
            (array[4.8,4.5,4.9,4.2,5.0,4.6])[i], (array[24,11,37,6,3,15])[i])
    on conflict (id) do nothing;
  end loop;

  -- seller_no, tur, cins, cinsiyet, adet, yas_min, yas_max (ay), agirlik_kg (sürüde ortalama), toplam_fiyat, satis_sekli, aciklama, il, ilce, lat, lng, kaç gün önce
  insert into public.listings (seller_id, tur, cins, cinsiyet, adet, yas_min, yas_max, agirlik_kg, toplam_fiyat, satis_sekli, aciklama, il, ilce, lat, lng, created_at)
  select s[v.k], v.tur, v.cins, v.cinsiyet, v.adet, v.y1, v.y2, v.kg, v.fiyat, v.sekil, '[ÖRNEK İLAN] ' || v.acik, v.il, v.ilce, v.lat, v.lng, now() - (v.gun || ' days')::interval
  from (values
    (1,'buyukbas','Simental','disi',1,24,24,520,216000,'birlikte','Gebe değil, sağlıklı, aşıları tam. Yerinde görülebilir.','Manisa','Salihli',38.48,28.14,1),
    (1,'buyukbas','Holstein','disi',1,30,30,580,225000,'birlikte','Günlük 28 litre süt verimli, ikinci buzağılama.','Manisa','Alaşehir',38.35,28.52,3),
    (3,'buyukbas','Montofon','erkek',1,18,18,450,195000,'birlikte','Besiye uygun, iştahlı genç tosun.','Balıkesir','Bandırma',40.35,27.97,2),
    (2,'buyukbas','Şarole','erkek',6,14,18,380,970000,'birlikte','Aynı çiftlikten 6 baş besilik dana. Toplu satış.','Konya','Cihanbeyli',38.65,32.92,4),
    (3,'buyukbas','Angus Melezi','karisik',12,8,12,260,1370000,'adet_adet','Besi başlangıcı için uygun, adet adet de satılır.','Balıkesir','Bandırma',40.35,27.97,6),
    (2,'kucukbas','Akkaraman','erkek',1,24,24,85,34000,'birlikte','Damızlık koç, soy kütüğü belgeli.','Konya','Karatay',37.87,32.56,1),
    (2,'kucukbas','Akkaraman','karisik',50,10,14,60,1170000,'adet_adet','Karışık sürü, kırkım yapılmış.','Konya','Karatay',37.87,32.56,2),
    (6,'kucukbas','Kıvırcık','erkek',30,8,10,48,590000,'birlikte','Kuzu sürüsü, mera ile beslendi.','Edirne','Keşan',40.86,26.63,5),
    (4,'kucukbas','Merinos','disi',120,12,36,55,2440000,'birlikte','Büyük sürü, aşıları tam, toplu satılık.','Aksaray','Eskil',38.40,33.41,7),
    (5,'kucukbas','Sakız','disi',15,14,20,52,312000,'adet_adet','Süt verimi yüksek, damızlık.','İzmir','Çeşme',38.32,26.30,3),
    (1,'kucukbas','Saanen Keçisi','disi',20,12,24,45,342000,'adet_adet','Süt keçisi sürüsü, ikizlik oranı yüksek.','Manisa','Kula',38.55,28.65,8),
    (4,'kucukbas','Dağlıç','erkek',40,6,8,38,640000,'birlikte','Kuzu sürüsü, kurbanlığa uygun değil, besilik.','Afyonkarahisar','Dinar',38.06,30.16,9),
    (1,'kanatli','Hindi','karisik',200,4,5,9,180000,'birlikte','Beyaz hindi, kesime yakın, toplu satış.','Manisa','Turgutlu',38.50,27.70,2),
    (6,'kanatli','Kaz','karisik',30,6,8,6,27000,'adet_adet','Kars kazı, serbest gezen.','Kars','Merkez',40.60,43.10,4),
    (5,'kanatli','Yumurtacı Tavuk','disi',500,18,24,2,54000,'birlikte','Yumurta verimi düşen sürü, toplu.','Denizli','Çardak',37.82,29.67,10),
    (4,'at','Arap Atı','erkek',1,60,60,450,180000,'birlikte','Binek, sakin yapılı, papersiz.','Ankara','Polatlı',39.58,32.15,5),
    (6,'at','Rahvan','disi',1,84,84,420,95000,'birlikte','Rahvan yürüyüşlü, eğitimli.','Erzurum','Aşkale',39.92,40.69,6)
  ) as v(k,tur,cins,cinsiyet,adet,y1,y2,kg,fiyat,sekil,acik,il,ilce,lat,lng,gun);
end $$;

select tur, count(*) as ilan, round(avg(kg_fiyat),0) as ort_kg_fiyat from public.listings group by tur order by tur;

-- TEMİZLEMEK İÇİN (örnek ilanları ve sahte satıcıları siler):
-- delete from auth.users where id::text like 'aaaaaaaa-0000-0000-0000-00000000000%';
