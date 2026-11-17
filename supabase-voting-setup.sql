-- Run this entire script in Supabase Dashboard -> SQL Editor.
-- Shared community votes for Fortnite cosmetics.

create table if not exists public.cosmetic_votes (
  id bigint generated always as identity primary key,
  item_key text not null,
  voter_id uuid not null,
  vote text not null check (vote in ('up', 'down')),
  created_at timestamptz not null default now(),
  constraint cosmetic_votes_one_vote_per_visitor unique (item_key, voter_id)
);

alter table public.cosmetic_votes enable row level security;

-- Visitors may submit a vote. The unique constraint prevents the same browser ID
-- from voting twice on the same cosmetic.
drop policy if exists "Visitors can submit cosmetic votes" on public.cosmetic_votes;
create policy "Visitors can submit cosmetic votes"
on public.cosmetic_votes
for insert
to anon, authenticated
with check (
  vote in ('up', 'down')
  and length(item_key) between 1 and 200
);

-- No direct table reads are exposed. Counts are returned through this aggregate function.
create or replace function public.get_cosmetic_vote_counts()
returns table (item_key text, upvotes bigint, downvotes bigint)
language sql
security definer
set search_path = ''
as $$
  select
    cv.item_key,
    count(*) filter (where cv.vote = 'up') as upvotes,
    count(*) filter (where cv.vote = 'down') as downvotes
  from public.cosmetic_votes as cv
  group by cv.item_key;
$$;

revoke all on function public.get_cosmetic_vote_counts() from public;
grant execute on function public.get_cosmetic_vote_counts() to anon, authenticated;
grant insert on public.cosmetic_votes to anon, authenticated;
