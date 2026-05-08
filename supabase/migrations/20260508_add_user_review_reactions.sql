alter table public.users
  add column if not exists review_likes jsonb not null default '{}'::jsonb,
  add column if not exists review_dislikes jsonb not null default '{}'::jsonb;

comment on column public.users.review_likes is
  'Review reactions keyed by review id, e.g. {"123": {"reviewId": "123", "updatedAt": "..."}}';

comment on column public.users.review_dislikes is
  'Review dislike reactions keyed by review id, e.g. {"123": {"reviewId": "123", "updatedAt": "..."}}';
