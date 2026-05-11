-- Migration 001: drop color_idx from time_entries
-- color_idx was used for per-card background colors, a feature that no longer exists.
alter table public.time_entries drop column if exists color_idx;
