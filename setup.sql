-- In Supabase: SQL Editor -> New query -> alles einfügen -> Run
-- Das Skript kann auch ausgeführt werden, wenn du die alte Version schon eingerichtet hast.

create table if not exists maps (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 1 and 60),
  sort serial
);
create unique index if not exists maps_name_unique on maps (lower(name));

create table if not exists scores (
  id uuid primary key default gen_random_uuid(),
  map_id uuid not null references maps(id) on delete cascade,
  name text not null check (char_length(name) between 1 and 30),
  ms integer not null check (ms > 0 and ms <= 86400000),
  created_at timestamptz not null default now()
);
alter table scores add column if not exists user_id uuid references auth.users(id) on delete set null;
create index if not exists scores_map_idx on scores (map_id, ms);
create index if not exists scores_user_idx on scores (user_id);

-- Name und Besitzer kommen immer vom eingeloggten Konto (nicht vom Browser)
create or replace function set_score_owner() returns trigger
language plpgsql set search_path = public as $$
begin
  new.user_id := auth.uid();
  -- auf 30 Zeichen kürzen (sonst schlägt der Check fehl), leerer Name -> 'unbekannt'
  new.name := coalesce(nullif(left(split_part(coalesce(auth.jwt() ->> 'email', ''), '@', 1), 30), ''), 'unbekannt');
  new.created_at := now();
  return new;
end $$;
drop trigger if exists score_owner on scores;
create trigger score_owner before insert on scores
  for each row execute function set_score_owner();

alter table maps enable row level security;
alter table scores enable row level security;

-- alte, offene Regeln entfernen
drop policy if exists "maps lesen" on maps;
drop policy if exists "maps anlegen" on maps;
drop policy if exists "scores lesen" on scores;
drop policy if exists "scores eintragen" on scores;
drop policy if exists "scores loeschen" on scores;
drop policy if exists "maps_select" on maps;
drop policy if exists "maps_insert" on maps;
drop policy if exists "scores_select" on scores;
drop policy if exists "scores_insert" on scores;
drop policy if exists "scores_delete" on scores;

-- Lesen darf jeder, Schreiben nur eingeloggt, Löschen nur eigene Zeiten
create policy "maps_select" on maps for select using (true);
create policy "maps_insert" on maps for insert to authenticated with check (true);
create policy "scores_select" on scores for select using (true);
create policy "scores_insert" on scores for insert to authenticated with check (user_id = auth.uid());
create policy "scores_delete" on scores for delete to authenticated using (user_id = auth.uid());

insert into maps (name) values
  ('Summer 1'),('Summer 2'),('Summer 3'),('Summer 4'),('Summer 5'),('Summer 6'),('Summer 7'),
  ('Winter 1'),('Winter 2'),('Winter 3'),('Winter 4'),('Winter 5'),
  ('Desert 1'),('Desert 2'),('Desert 3'),('Desert 4'),('Desert 5')
on conflict do nothing;
