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
  ('🔥 지금 뜨는 맛집', 1),
  ('많이 찾는 맛집👍', 2),
  ('✨ 신상 맛집 ✨', 3),
  ('🕰️ 추억의 맛집', 4)
on conflict (label) do update set
  sort_order = excluded.sort_order,
  is_active = true,
  updated_at = now();

update trending_chips
set is_active = false,
    updated_at = now()
where label not in (
  '🔥 지금 뜨는 맛집',
  '많이 찾는 맛집👍',
  '✨ 신상 맛집 ✨',
  '🕰️ 추억의 맛집'
);

-- =========================================================
-- SEARCH RELATED KEYWORDS
-- Input-while-typing related keyword chips.
-- Backend matches the user's query against triggers from this table.
-- group_key can be used by backend ranking logic, e.g. cafe intent.
-- =========================================================

create table if not exists search_related_keywords (
  id text primary key,
  group_key text not null,
  label text not null,
  keyword text not null,
  triggers text[] not null default '{}',
  is_exclusive boolean not null default false,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists search_related_keywords_group_idx
  on search_related_keywords (group_key);

create index if not exists search_related_keywords_active_order_idx
  on search_related_keywords (is_active, is_exclusive desc, sort_order);

insert into search_related_keywords (
  id,
  group_key,
  label,
  keyword,
  triggers,
  is_exclusive,
  sort_order,
  is_active
)
values
  (
    'coffee-franchise-cafe',
    'coffeebean',
    '프랜차이즈 카페',
    '프랜차이즈 카페',
    array['커피빈', '커피빈코리아', 'coffee bean', 'coffeebean', 'the coffee bean'],
    true,
    1,
    true
  ),
  (
    'coffee-tumbler-md',
    'coffeebean',
    '텀블러MD',
    '텀블러MD',
    array['커피빈', '커피빈코리아', 'coffee bean', 'coffeebean', 'the coffee bean'],
    true,
    2,
    true
  ),
  (
    'coffee-americano',
    'coffeebean',
    '아메리카노',
    '아메리카노',
    array['커피빈', '커피빈코리아', 'coffee bean', 'coffeebean', 'the coffee bean'],
    true,
    3,
    true
  ),
  (
    'cafe-quiet-study',
    'cafe',
    '공부하기 좋은 조용한 카페',
    '공부하기 좋은 조용한 카페',
    array['커피', '카페', '라떼', '디카페인', '돌체', '돌체라떼', '스타벅스', '투썸', '이디야', '할리스', '메가커피', '컴포즈커피', '빽다방', '폴바셋'],
    false,
    10,
    true
  ),
  (
    'cafe-late-night',
    'cafe',
    '늦게까지 하는 카페',
    '늦게까지 하는 카페',
    array['커피', '카페', '라떼', '디카페인', '돌체', '돌체라떼', '스타벅스', '투썸', '이디야', '할리스', '메가커피', '컴포즈커피', '빽다방', '폴바셋'],
    false,
    11,
    true
  ),
  (
    'cafe-sweet-latte',
    'cafe',
    '달달한 라떼',
    '달달한 라떼',
    array['커피', '카페', '라떼', '디카페인', '돌체', '돌체라떼', '스타벅스', '투썸', '이디야', '할리스', '메가커피', '컴포즈커피', '빽다방', '폴바셋'],
    false,
    12,
    true
  ),
  (
    'cafe-decaf-menu',
    'cafe',
    '디카페인 추천',
    '디카페인 추천',
    array['커피', '카페', '라떼', '디카페인', '돌체', '돌체라떼', '스타벅스', '투썸', '이디야', '할리스', '메가커피', '컴포즈커피', '빽다방', '폴바셋'],
    false,
    13,
    true
  ),
  (
    'cafe-long-stay',
    'cafe',
    '오래 머물기 좋은 분위기',
    '오래 머물기 좋은 분위기',
    array['커피', '카페', '라떼', '디카페인', '돌체', '돌체라떼', '스타벅스', '투썸', '이디야', '할리스', '메가커피', '컴포즈커피', '빽다방', '폴바셋'],
    false,
    14,
    true
  ),
  (
    'cafe-outlets',
    'cafe',
    '콘센트 많은 카페',
    '콘센트 많은 카페',
    array['커피', '카페', '라떼', '디카페인', '돌체', '돌체라떼', '스타벅스', '투썸', '이디야', '할리스', '메가커피', '컴포즈커피', '빽다방', '폴바셋'],
    false,
    15,
    true
  ),
  (
    'cafe-less-crowded',
    'cafe',
    '현재 사람 적은 카페',
    '현재 사람 적은 카페',
    array['커피', '카페', '라떼', '디카페인', '돌체', '돌체라떼', '스타벅스', '투썸', '이디야', '할리스', '메가커피', '컴포즈커피', '빽다방', '폴바셋'],
    false,
    16,
    true
  ),
  (
    'cafe-quiet-work',
    'cafe',
    '조용하게 작업하기 좋은 곳',
    '조용하게 작업하기 좋은 곳',
    array['커피', '카페', '라떼', '디카페인', '돌체', '돌체라떼', '스타벅스', '투썸', '이디야', '할리스', '메가커피', '컴포즈커피', '빽다방', '폴바셋'],
    false,
    17,
    true
  )
on conflict (id) do update set
  group_key = excluded.group_key,
  label = excluded.label,
  keyword = excluded.keyword,
  triggers = excluded.triggers,
  is_exclusive = excluded.is_exclusive,
  sort_order = excluded.sort_order,
  is_active = excluded.is_active,
  updated_at = now();

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
