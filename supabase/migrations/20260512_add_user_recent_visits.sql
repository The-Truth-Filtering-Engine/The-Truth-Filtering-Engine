alter table public.users
  add column if not exists recent_visits jsonb not null default '{}'::jsonb;

comment on column public.users.recent_visits is
  'Recently viewed stores keyed by store id, e.g. {"place-id": {"storeId": "place-id", "name": "...", "updatedAt": "..."}}';
