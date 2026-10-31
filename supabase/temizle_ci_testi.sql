-- Otomatik testin yanlışlıkla senin test hesabına bıraktığı kayıtları siler.
-- Supabase > SQL Editor'de BİR KEZ çalıştır (002_ek_ozellikler.sql'den ÖNCE).
delete from public.reviews where comment = 'CI yorumu';
delete from public.reports where detail = 'CI testi';
delete from public.conversations where id in (select conversation_id from public.messages where body = 'Merhaba, CI testi');

-- Yorum silinince sahte satıcıların puanı sıfırlanır; örnek değerlerini geri yükle.
update public.profiles p set rating_avg = v.a, rating_count = v.n
from (values
  ('aaaaaaaa-0000-0000-0000-000000000001'::uuid, 4.8, 24),
  ('aaaaaaaa-0000-0000-0000-000000000002'::uuid, 4.5, 11),
  ('aaaaaaaa-0000-0000-0000-000000000003'::uuid, 4.9, 37),
  ('aaaaaaaa-0000-0000-0000-000000000004'::uuid, 4.2, 6),
  ('aaaaaaaa-0000-0000-0000-000000000005'::uuid, 5.0, 3),
  ('aaaaaaaa-0000-0000-0000-000000000006'::uuid, 4.6, 15)
) as v(id, a, n) where p.id = v.id;
