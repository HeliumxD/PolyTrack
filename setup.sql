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
  ('Summer 1'),('Summer 2'),('Summer 3'),('Summer 4'),('Summer 5'),
  ('Winter 1'),('Winter 2'),('Winter 3'),('Winter 4'),('Winter 5'),
  ('Desert 1'),('Desert 2'),('Desert 3'),('Desert 4'),('Desert 5')
on conflict do nothing;

-- ---------- Freigaben für die Webseite (neuere Supabase-Projekte machen das nicht mehr automatisch) ----------
grant usage on schema public to anon, authenticated;
grant select on maps, scores to anon, authenticated;
grant insert on maps, scores to authenticated;
grant delete on scores to authenticated;
grant usage, select on all sequences in schema public to authenticated;

-- ---------- Chat ----------
create table if not exists messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  name text not null check (char_length(name) between 1 and 30),
  text text not null check (char_length(btrim(text)) between 1 and 500),
  created_at timestamptz not null default now()
);
create index if not exists messages_created_idx on messages (created_at);

-- Absender, Name und Zeit kommen immer vom Server (nicht vom Browser)
create or replace function set_message_owner() returns trigger
language plpgsql set search_path = public as $$
begin
  new.user_id := auth.uid();
  new.name := coalesce(nullif(left(split_part(coalesce(auth.jwt() ->> 'email', ''), '@', 1), 30), ''), 'unbekannt');
  new.text := btrim(new.text);
  new.created_at := now();
  return new;
end $$;
drop trigger if exists message_owner on messages;
create trigger message_owner before insert on messages
  for each row execute function set_message_owner();

alter table messages enable row level security;
drop policy if exists "messages_select" on messages;
drop policy if exists "messages_insert" on messages;
drop policy if exists "messages_delete" on messages;
-- Chat lesen und schreiben nur eingeloggt, löschen nur eigene Nachrichten
create policy "messages_select" on messages for select to authenticated using (true);
create policy "messages_insert" on messages for insert to authenticated with check (user_id = auth.uid());
create policy "messages_delete" on messages for delete to authenticated using (user_id = auth.uid());

grant select, insert, delete on messages to authenticated;

-- ---------- Weltrekord pro Map (manuell eingetragen) ----------
alter table maps add column if not exists wr_ms integer check (wr_ms is null or (wr_ms > 0 and wr_ms <= 86400000));
alter table maps add column if not exists wr_name text check (wr_name is null or char_length(wr_name) <= 40);
-- Eingeloggte dürfen bei Maps nur den Weltrekord ändern (nicht den Namen o. Ä.)
drop policy if exists "maps_update_wr" on maps;
create policy "maps_update_wr" on maps for update to authenticated using (true) with check (true);
grant update (wr_ms, wr_name) on maps to authenticated;
