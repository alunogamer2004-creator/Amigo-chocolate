-- Amigo Chocolate: esquema seguro para Supabase/PostgreSQL
-- Antes de executar, substitua TROQUE-ESTE-CODIGO por um código forte e exclusivo.
-- Execute este arquivo uma única vez em um projeto Supabase dedicado ao Amigo Chocolate.

-- ---------- schema privado para função auxiliar ----------
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- ---------- tabelas ----------
create table if not exists public.game (
  id int primary key default 1 check (id = 1),
  drawn boolean not null default false,
  drawn_at timestamptz
);
insert into public.game (id) values (1) on conflict do nothing;

create table if not exists public.config (
  key text primary key,
  value text not null
);
insert into public.config (key, value)
values ('admin_code', 'TROQUE-ESTE-CODIGO')
on conflict (key) do update
  set value = excluded.value
  where public.config.value = 'TROQUE-ESTE-CODIGO';

do $$
begin
  if exists (
    select 1 from public.config
    where key = 'admin_code' and value = 'TROQUE-ESTE-CODIGO'
  ) then
    raise exception 'Antes de executar, substitua TROQUE-ESTE-CODIGO por um código forte no arquivo schema.sql.';
  end if;
end;
$$;

create table if not exists public.players (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 1 and 40),
  created_at timestamptz not null default now()
);
create unique index if not exists players_name_unique
  on public.players (lower(btrim(name)));

create table if not exists public.assignments (
  giver uuid primary key references public.players (id) on delete cascade,
  receiver uuid not null references public.players (id) on delete cascade,
  revealed_at timestamptz
);

-- ---------- segurança por linha (RLS) ----------
alter table public.game enable row level security;
alter table public.config enable row level security;
alter table public.players enable row level security;
alter table public.assignments enable row level security;

-- Somente participantes autenticados (inclusive usuários anônimos do Supabase Auth)
-- podem consultar a lista de participantes e o estado público do sorteio.
drop policy if exists game_read on public.game;
create policy game_read on public.game
  for select to authenticated using (true);

drop policy if exists players_read on public.players;
create policy players_read on public.players
  for select to authenticated using (true);

-- Remova policies antigas de escrita caso a versão anterior do SQL já tenha sido usada.
drop policy if exists players_insert on public.players;
drop policy if exists players_delete on public.players;

-- config e assignments não recebem policies: não podem ser lidas diretamente pela API.
-- Inscrição/saída são feitas por funções que bloqueiam a linha do jogo para evitar
-- corrida entre a inscrição de alguém e o início do sorteio.

-- ---------- função auxiliar privada ----------
create or replace function private._check_admin(p_code text)
returns void
language plpgsql
set search_path = ''
as $$
begin
  if p_code is null or p_code is distinct from (
    select c.value from public.config as c where c.key = 'admin_code'
  ) then
    raise exception 'Código do organizador inválido';
  end if;
end;
$$;

-- ---------- funções públicas chamadas pelo site ----------
create or replace function public.join_game(p_name text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_drawn boolean;
  v_name text;
begin
  if auth.uid() is null then
    raise exception 'Sessão inválida. Atualize a página e tente novamente.';
  end if;

  v_name := btrim(coalesce(p_name, ''));
  if char_length(v_name) not between 1 and 40 then
    raise exception 'Digite um nome com até 40 caracteres.';
  end if;

  select g.drawn into v_drawn
  from public.game as g
  where g.id = 1
  for update;

  if v_drawn then
    raise exception 'As inscrições já foram encerradas.';
  end if;

  insert into public.players (id, name)
  values (auth.uid(), v_name);
end;
$$;

create or replace function public.leave_game()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_drawn boolean;
begin
  if auth.uid() is null then
    raise exception 'Sessão inválida. Atualize a página e tente novamente.';
  end if;

  select g.drawn into v_drawn
  from public.game as g
  where g.id = 1
  for update;

  if v_drawn then
    raise exception 'As inscrições já foram encerradas.';
  end if;

  delete from public.players where id = auth.uid();
end;
$$;

create or replace function public.my_status()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'drawn', (select g.drawn from public.game as g where g.id = 1),
    'has_assignment', exists (
      select 1 from public.assignments as a where a.giver = auth.uid()
    ),
    'revealed', coalesce((
      select a.revealed_at is not null
      from public.assignments as a
      where a.giver = auth.uid()
    ), false)
  );
$$;

create or replace function public.reveal()
returns table (out_name text, first_time boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_recv uuid;
  v_first boolean;
begin
  if auth.uid() is null then
    raise exception 'Sessão inválida. Atualize a página e tente novamente.';
  end if;

  select a.receiver, (a.revealed_at is null)
    into v_recv, v_first
  from public.assignments as a
  where a.giver = auth.uid();

  if v_recv is null then
    raise exception 'Você não está neste sorteio.';
  end if;

  update public.assignments as a
  set revealed_at = coalesce(a.revealed_at, now())
  where a.giver = auth.uid();

  return query
    select p.name, v_first
    from public.players as p
    where p.id = v_recv;
end;
$$;

create or replace function public.admin_run_draw(p_code text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_drawn boolean;
  n int;
begin
  perform private._check_admin(p_code);

  select g.drawn into v_drawn
  from public.game as g
  where g.id = 1
  for update;

  if v_drawn then
    raise exception 'O sorteio já foi feito.';
  end if;

  select count(*) into n from public.players;
  if n < 3 then
    raise exception 'São necessários pelo menos 3 inscritos.';
  end if;

  delete from public.assignments;

  -- Um ciclo único embaralhado: ninguém tira a si mesmo e cada pessoa é tirada uma vez.
  with ordered_players as (
    select
      p.id,
      row_number() over (order by random()) as rn,
      count(*) over () as total
    from public.players as p
  )
  insert into public.assignments (giver, receiver)
  select a.id, b.id
  from ordered_players as a
  join ordered_players as b
    on b.rn = case when a.rn = a.total then 1 else a.rn + 1 end;

  update public.game
  set drawn = true, drawn_at = now()
  where id = 1;
end;
$$;

create or replace function public.admin_reset(p_code text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private._check_admin(p_code);

  perform 1
  from public.game as g
  where g.id = 1
  for update;

  delete from public.assignments;
  update public.game
  set drawn = false, drawn_at = null
  where id = 1;
end;
$$;

create or replace function public.admin_remove_player(p_code text, p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_drawn boolean;
begin
  perform private._check_admin(p_code);

  select g.drawn into v_drawn
  from public.game as g
  where g.id = 1
  for update;

  if v_drawn then
    raise exception 'Reabra as inscrições para remover alguém.';
  end if;

  delete from public.players where id = p_id;
end;
$$;

create or replace function public.admin_status(p_code text)
returns table (id uuid, name text, revealed boolean)
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private._check_admin(p_code);

  return query
    select p.id, p.name, (a.revealed_at is not null)
    from public.players as p
    left join public.assignments as a on a.giver = p.id
    order by p.name;
end;
$$;

create or replace function public.admin_release(p_code text, p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_drawn boolean;
begin
  perform private._check_admin(p_code);

  select g.drawn into v_drawn
  from public.game as g
  where g.id = 1
  for update;

  if not v_drawn then
    raise exception 'O sorteio ainda não foi feito.';
  end if;

  update public.assignments
  set revealed_at = null
  where giver = p_id;
end;
$$;

-- ---------- privilégios mínimos para a Data API ----------
-- Usuários anônimos do Supabase Auth usam a role authenticated.
grant usage on schema public to authenticated;

-- Remova permissões amplas herdadas e libere somente o necessário.
revoke all privileges on table
  public.game, public.config, public.players, public.assignments
from public, anon, authenticated;

grant select on table public.game, public.players to authenticated;

-- O site não acessa config nem assignments diretamente; usa apenas RPCs autorizadas.
revoke all on function private._check_admin(text) from public, anon, authenticated;
revoke all on function public.join_game(text) from public, anon, authenticated;
revoke all on function public.leave_game() from public, anon, authenticated;
revoke all on function public.my_status() from public, anon, authenticated;
revoke all on function public.reveal() from public, anon, authenticated;
revoke all on function public.admin_run_draw(text) from public, anon, authenticated;
revoke all on function public.admin_reset(text) from public, anon, authenticated;
revoke all on function public.admin_remove_player(text, uuid) from public, anon, authenticated;
revoke all on function public.admin_status(text) from public, anon, authenticated;
revoke all on function public.admin_release(text, uuid) from public, anon, authenticated;

grant execute on function public.join_game(text) to authenticated;
grant execute on function public.leave_game() to authenticated;
grant execute on function public.my_status() to authenticated;
grant execute on function public.reveal() to authenticated;
grant execute on function public.admin_run_draw(text) to authenticated;
grant execute on function public.admin_reset(text) to authenticated;
grant execute on function public.admin_remove_player(text, uuid) to authenticated;
grant execute on function public.admin_status(text) to authenticated;
grant execute on function public.admin_release(text, uuid) to authenticated;
