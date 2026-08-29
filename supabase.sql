-- English Lab · синхронизация между устройствами
-- Выполнить один раз в Supabase → SQL Editor → Run

create table if not exists public.el_sync (
  k          text primary key,
  d          jsonb not null,
  updated_at timestamptz not null default now()
);

-- прямой доступ к таблице по API закрыт полностью
alter table public.el_sync enable row level security;
revoke all on public.el_sync from anon, authenticated;

-- читать и писать можно только через функции, зная свой ключ
create or replace function public.el_get(k text)
returns jsonb
language sql security definer set search_path = public as $$
  select d from public.el_sync where public.el_sync.k = el_get.k;
$$;

create or replace function public.el_put(k text, d jsonb)
returns timestamptz
language sql security definer set search_path = public as $$
  insert into public.el_sync as t (k, d, updated_at)
  values (el_put.k, el_put.d, now())
  on conflict (k) do update set d = excluded.d, updated_at = now()
  returning t.updated_at;
$$;

grant execute on function public.el_get(text)         to anon;
grant execute on function public.el_put(text, jsonb)  to anon;
