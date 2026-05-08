-- ============================================================
-- LTT (Lucy's Time Tracker) — Supabase schema
-- Run this in the Supabase SQL Editor
-- ============================================================

-- 1. TIME ENTRIES TABLE
create table if not exists public.time_entries (
  id            bigint       primary key,               -- JS Date.now() timestamp used as ID
  user_id       uuid         not null references auth.users(id) on delete cascade,
  name          text         not null,
  ms            bigint       not null default 0,         -- tracked milliseconds
  ts            bigint       not null,                   -- entry timestamp (ms since epoch)
  color_idx     integer      not null default 0,
  untracked     boolean      not null default false,
  sort_order    integer,
  jira_key      text,
  jira_summary  text,
  jira_desc     text                  default '',
  jira_sent     boolean      not null default false,
  client_name   text,
  deleted_from_bulk boolean  not null default false,
  carried_over  boolean      not null default false,
  created_at    timestamptz  not null default now(),
  updated_at    timestamptz  not null default now()
);

alter table public.time_entries enable row level security;

create policy "Users see and manage only their own entries"
  on public.time_entries
  for all
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create index if not exists time_entries_user_ts on public.time_entries (user_id, ts desc);

-- Grant table-level access to the authenticated role (required even with RLS)
grant usage on schema public to authenticated;
grant select, insert, update, delete on public.time_entries to authenticated;


-- 2. USER SETTINGS TABLE
-- All settings stored as a single JSONB blob per user for flexibility.
-- Keys stored: ltt_title, ltt_gradient, ltt_proxy_url, slack_channel, slack_user_id,
--              slack_webhook, ltt_bg_image, ltt_noise,
--              jira_access_token, jira_refresh_token, jira_token_expiry,
--              jira_cloud_id, jira_site_name, jira_user_name, jira_user_email,
--              jira_account_id, jira_client_secret (app secret only, no tokens in plain text)
create table if not exists public.user_settings (
  user_id     uuid         primary key references auth.users(id) on delete cascade,
  settings    jsonb        not null default '{}',
  created_at  timestamptz  not null default now(),
  updated_at  timestamptz  not null default now()
);

alter table public.user_settings enable row level security;

create policy "Users see and manage only their own settings"
  on public.user_settings
  for all
  using  (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- Grant table-level access to the authenticated role
grant select, insert, update, delete on public.user_settings to authenticated;


-- 3. AUTO-UPDATE updated_at TRIGGER
create or replace function public.handle_updated_at()
returns trigger language plpgsql security definer as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists on_time_entries_updated on public.time_entries;
create trigger on_time_entries_updated
  before update on public.time_entries
  for each row execute procedure public.handle_updated_at();

drop trigger if exists on_user_settings_updated on public.user_settings;
create trigger on_user_settings_updated
  before update on public.user_settings
  for each row execute procedure public.handle_updated_at();
