alter table public.users
  add column if not exists recent_visits jsonb not null default '{}'::jsonb;

comment on column public.users.recent_visits is
  'Recently viewed review entries keyed by reviews.id, e.g. {"123": {"name": "...", "review_url": "...", "review_title": "...", "review_description": "...", "visitedAt": "..."}}';
