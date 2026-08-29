-- English Lab · синхронизация между устройствами
-- Выполнить один раз: Supabase → SQL Editor → New query → вставить → Run

create table if not exists public.el_sync (
  k          text primary key,
  d          jsonb not null,
  updated_at timestamptz not null default now()
);

-- прямой доступ к таблице по API закрыт полностью
alter table public.el_sync enable row level security;
revoke all on public.el_sync from anon, authenticated;

-- читать можно только зная свой ключ
create or replace function public.el_get(k text)
returns jsonb
language sql security definer set search_path = public as $$
  select d from public.el_sync where public.el_sync.k = el_get.k;
$$;

-- писать тоже, плюс ограничения против злоупотребления публичным ключом
drop function if exists public.el_put(text, jsonb);

create or replace function public.el_put(p_k text, p_d jsonb)
returns timestamptz
language plpgsql security definer set search_path = public as $$
declare ts timestamptz;
begin
  if length(p_k) < 20 or length(p_k) > 64 then
    raise exception 'bad key';
  end if;
  if pg_column_size(p_d) > 4194304 then
    raise exception 'too large';
  end if;
  if not exists (select 1 from public.el_sync s where s.k = p_k)
     and (select count(*) from public.el_sync) >= 20 then
    raise exception 'storage full';
  end if;

  insert into public.el_sync as t (k, d, updated_at)
  values (p_k, p_d, now())
  on conflict (k) do update set d = excluded.d, updated_at = now()
  returning t.updated_at into ts;

  return ts;
end;
$$;

grant execute on function public.el_get(text)        to anon;
grant execute on function public.el_put(text, jsonb) to anon;
