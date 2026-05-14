-- =========================================================
-- Search schema v2 additions for Supabase SQL Editor.
--
-- Apply after search_schema.sql.
--
-- Notes:
-- - External place storage uses existing restaurants + restaurant_place_mappings.
-- - trending_chips intentionally keeps only label for the app/search query.
-- - No query, icon_key, or emoji columns are used.
-- =========================================================

-- =========================================================
-- TRENDING CHIPS
-- Input-before-search curated chips.
-- =========================================================

create table if not exists trending_chips (
  id serial primary key,
  label text not null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  updated_at timestamptz not null default now()
);

create unique index if not exists trending_chips_label_unique_idx
  on trending_chips (label);

insert into trending_chips (label, sort_order)
values
  ('실시간 검색 맛집', 1),
  ('많이 찾는 맛집', 2),
  ('✨ 신상 맛집 ✨', 3),
  ('데이트 장소', 4),
  ('SNS 좋아요', 5),
  ('힐링 맛집', 6),
  ('예쁜 카페', 7),
  ('이색 맛집', 8),
  ('지역 전통 음식', 9),
  ('고급 식당', 10),
  ('TV 출연 가게', 11),
  ('동네 오래된 맛집', 12)
on conflict (label) do update set
  sort_order = excluded.sort_order,
  is_active = true,
  updated_at = now();

update trending_chips
set is_active = false,
    updated_at = now()
where label not in (
  '실시간 검색 맛집',
  '많이 찾는 맛집',
  '✨ 신상 맛집 ✨',
  '데이트 장소',
  'SNS 좋아요',
  '힐링 맛집',
  '예쁜 카페',
  '이색 맛집',
  '지역 전통 음식',
  '고급 식당',
  'TV 출연 가게',
  '동네 오래된 맛집'
);

-- =========================================================
-- SEARCH CACHE
-- Prevent repeated external API calls for the same normalized query.
-- =========================================================

create table if not exists search_cache (
  query text primary key,
  result_count integer not null default 0,
  expires_at timestamptz not null,
  created_at timestamptz not null default now()
);

create index if not exists search_cache_expires_idx
  on search_cache (expires_at);

create or replace function cleanup_expired_search_cache()
returns void
language sql
as $$
  delete from search_cache where expires_at < now();
$$;

-- =========================================================
-- SEARCH KEYWORD STATS
-- First search collects issue keyword matches for better chips later.
-- =========================================================

create table if not exists search_keyword_stats (
  query text not null,
  issue_keyword_id text not null
    references search_issue_keywords(id) on delete cascade,
  match_count integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key (query, issue_keyword_id)
);

create index if not exists search_keyword_stats_issue_idx
  on search_keyword_stats (issue_keyword_id);
