-- GameStatus Chess Arena: paste this entire file into Supabase SQL Editor and run.
create extension if not exists pgcrypto;
create table if not exists public.chess_profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 username text unique not null check (char_length(username) between 3 and 18),
 elo integer not null default 1200,
 games_played integer not null default 0,
 wins integer not null default 0,
 losses integer not null default 0,
 draws integer not null default 0,
 created_at timestamptz not null default now()
);
create table if not exists public.chess_games (
 id uuid primary key default gen_random_uuid(),
 white_id uuid not null references public.chess_profiles(id),
 black_id uuid not null references public.chess_profiles(id),
 fen text not null default 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
 status text not null default 'active' check(status in ('active','finished')),
 result text check(result in ('white','black','draw')),
 created_at timestamptz not null default now(),
 finished_at timestamptz,
 check(white_id <> black_id)
);
create table if not exists public.chess_queue (
 user_id uuid primary key references public.chess_profiles(id) on delete cascade,
 created_at timestamptz not null default now(),
 game_id uuid references public.chess_games(id) on delete set null
);
alter table public.chess_profiles enable row level security;
alter table public.chess_games enable row level security;
alter table public.chess_queue enable row level security;
drop policy if exists "profiles are public" on public.chess_profiles;
create policy "profiles are public" on public.chess_profiles for select using(true);
drop policy if exists "users create own profile" on public.chess_profiles;
create policy "users create own profile" on public.chess_profiles for insert to authenticated with check(auth.uid()=id);
drop policy if exists "users update own profile" on public.chess_profiles;
drop policy if exists "players see their games" on public.chess_games;
create policy "players see their games" on public.chess_games for select to authenticated using(auth.uid()=white_id or auth.uid()=black_id);
drop policy if exists "players see own queue" on public.chess_queue;
create policy "players see own queue" on public.chess_queue for select to authenticated using(auth.uid()=user_id);
drop policy if exists "players leave own queue" on public.chess_queue;
create policy "players leave own queue" on public.chess_queue for delete to authenticated using(auth.uid()=user_id);
create or replace function public.chess_new_profile() returns trigger language plpgsql security definer set search_path=public as $$
declare chosen text;
begin
 chosen := coalesce(nullif(new.raw_user_meta_data->>'username',''), 'Player' || substr(new.id::text,1,6));
 chosen := left(regexp_replace(chosen,'[^a-zA-Z0-9_]','','g'),18);
 insert into public.chess_profiles(id,username) values(new.id,chosen) on conflict(id) do nothing;
 return new;
end $$;
drop trigger if exists chess_auth_profile on auth.users;
create trigger chess_auth_profile after insert on auth.users for each row execute procedure public.chess_new_profile();
create or replace function public.chess_join_queue() returns jsonb language plpgsql security definer set search_path=public as $$
declare me uuid:=auth.uid(); opponent uuid; gid uuid;
begin
 if me is null then raise exception 'Sign in first'; end if;
 delete from public.chess_queue where user_id=me;
 select user_id into opponent from public.chess_queue where user_id<>me and game_id is null order by created_at for update skip locked limit 1;
 if opponent is not null then
   if random()<0.5 then insert into public.chess_games(white_id,black_id) values(me,opponent) returning id into gid;
   else insert into public.chess_games(white_id,black_id) values(opponent,me) returning id into gid; end if;
   update public.chess_queue set game_id=gid where user_id=opponent;
   insert into public.chess_queue(user_id,game_id) values(me,gid);
   return jsonb_build_object('game_id',gid);
 end if;
 insert into public.chess_queue(user_id) values(me);
 return jsonb_build_object('waiting',true);
end $$;
-- Beta-only move sync. A production release needs trusted server-side move legality/turn validation.
create or replace function public.chess_submit_move(p_game_id uuid,p_fen text,p_san text) returns void language plpgsql security definer set search_path=public as $$
begin
 update public.chess_games set fen=p_fen where id=p_game_id and status='active' and auth.uid() in (white_id,black_id);
 if not found then raise exception 'Game not found or you are not a player'; end if;
end $$;
create or replace function public.chess_resign_game(p_game_id uuid,p_result text) returns void language plpgsql security definer set search_path=public as $$
declare g public.chess_games%rowtype; rw integer; rb integer; ew numeric; eb numeric; sw numeric; sb numeric;
begin
 select * into g from public.chess_games where id=p_game_id and status='active' for update;
 if not found or auth.uid() not in (g.white_id,g.black_id) then raise exception 'Game not found'; end if;
 if p_result not in ('white','black','draw') then raise exception 'Invalid result'; end if;
 if (p_result='white' and auth.uid()<>g.black_id) or (p_result='black' and auth.uid()<>g.white_id) then raise exception 'Only the resigning player can submit this result'; end if;
 select elo into rw from public.chess_profiles where id=g.white_id;
 select elo into rb from public.chess_profiles where id=g.black_id;
 ew:=1/(1+power(10::numeric,(rb-rw)/400.0)); eb:=1-ew;
 sw:=case p_result when 'white' then 1 when 'draw' then .5 else 0 end; sb:=1-sw;
 update public.chess_profiles set elo=greatest(100,round(rw+32*(sw-ew))::int),games_played=games_played+1,wins=wins+(case when sw=1 then 1 else 0 end),losses=losses+(case when sw=0 then 1 else 0 end),draws=draws+(case when sw=.5 then 1 else 0 end) where id=g.white_id;
 update public.chess_profiles set elo=greatest(100,round(rb+32*(sb-eb))::int),games_played=games_played+1,wins=wins+(case when sb=1 then 1 else 0 end),losses=losses+(case when sb=0 then 1 else 0 end),draws=draws+(case when sb=.5 then 1 else 0 end) where id=g.black_id;
 update public.chess_games set status='finished',result=p_result,finished_at=now() where id=p_game_id;
 delete from public.chess_queue where game_id=p_game_id;
end $$;
grant execute on function public.chess_join_queue() to authenticated;
grant execute on function public.chess_submit_move(uuid,text,text) to authenticated;
grant execute on function public.chess_resign_game(uuid,text) to authenticated;
do $$ begin alter publication supabase_realtime add table public.chess_games; exception when duplicate_object then null; end $$;
