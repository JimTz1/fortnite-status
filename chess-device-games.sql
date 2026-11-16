-- Chess Arena upgrade: device-based anonymous profiles and private game codes.
-- Run this once in Supabase SQL Editor AFTER chess-setup.sql.
alter table public.chess_games alter column black_id drop not null;
alter table public.chess_games add column if not exists room_code text unique;
alter table public.chess_games drop constraint if exists chess_games_status_check;
alter table public.chess_games add constraint chess_games_status_check
  check (status in ('waiting','active','finished'));

create or replace function public.chess_create_game()
returns jsonb language plpgsql security definer set search_path=public as $$
declare me uuid := auth.uid(); code text; gid uuid;
begin
  if me is null then raise exception 'Create a device player first'; end if;
  if not exists(select 1 from public.chess_profiles where id=me) then
    raise exception 'Player profile is still being created. Try again.';
  end if;
  loop
    code := upper(substr(encode(gen_random_bytes(6),'hex'),1,6));
    exit when not exists(select 1 from public.chess_games where room_code=code);
  end loop;
  insert into public.chess_games(white_id,black_id,status,room_code)
  values(me,null,'waiting',code) returning id into gid;
  return jsonb_build_object('game_id',gid,'code',code);
end $$;

create or replace function public.chess_join_code(p_code text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare me uuid := auth.uid(); g public.chess_games%rowtype;
begin
  if me is null then raise exception 'Create a device player first'; end if;
  select * into g from public.chess_games
    where room_code=upper(trim(p_code)) and status='waiting'
    for update;
  if not found then raise exception 'Game code not found or the game is already full'; end if;
  if g.white_id=me then raise exception 'You cannot join your own game'; end if;
  if not exists(select 1 from public.chess_profiles where id=me) then
    raise exception 'Player profile is still being created. Try again.';
  end if;
  update public.chess_games set black_id=me,status='active' where id=g.id;
  return jsonb_build_object('game_id',g.id);
end $$;

grant execute on function public.chess_create_game() to authenticated;
grant execute on function public.chess_join_code(text) to authenticated;
