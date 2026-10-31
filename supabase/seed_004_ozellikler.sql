-- ÖRNEK ilanlara amaç/belge/pazarlık/teslimat bilgisi ekler (sadece test). 004_ozellikler.sql'den sonra çalıştır.
update public.listings set
  amac = case
    when tur = 'buyukbas' and cinsiyet = 'disi' and cins = 'Holstein' then 'sut_yumurta'
    when tur = 'buyukbas' and cinsiyet = 'disi' then 'damizlik'
    when tur = 'buyukbas' then 'besi'
    when tur = 'kucukbas' and cinsiyet = 'erkek' then 'kurbanlik'
    when tur = 'kucukbas' and cinsiyet = 'disi' then 'damizlik'
    when tur = 'kucukbas' then 'besi'
    when tur = 'kanatli' and cins ilike '%tavuk%' then 'sut_yumurta'
    when tur = 'kanatli' then 'kesim'
    else 'diger' end,
  belgeler = case
    when tur = 'buyukbas' and mod(abs(hashtext(id::text)), 2) = 0 then array['kupe','pasaport','saglik_raporu','asi']
    when tur = 'buyukbas' then array['kupe','pasaport']
    when tur = 'kucukbas' and mod(abs(hashtext(id::text)), 2) = 0 then array['kupe','nakil','asi']
    when tur = 'kucukbas' then array['kupe']
    when tur = 'at' then array['pasaport']
    else '{}'::text[] end,
  pazarlik = mod(abs(hashtext(id::text)), 3) = 0,
  teslimat = (array['yerinde','ikisi','nakliye'])[mod(abs(hashtext(id::text)), 3) + 1],
  goruntulenme = 20 + mod(abs(hashtext(id::text)), 180)
where aciklama like '[ÖRNEK İLAN]%';

select amac, count(*) from public.listings group by amac order by 1;
