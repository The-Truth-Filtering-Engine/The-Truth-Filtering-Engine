-- =========================================================
-- Search MVP schema for Supabase SQL Editor.
--
-- Design:
-- 1. restaurants is the internal restaurant entity.
-- 2. restaurant_place_mappings connects internal restaurants to external places.
-- 3. restaurant_menus keeps restaurant_name for current search_preview.py compatibility.
-- 4. Search history is separate from activity-history.
-- =========================================================

-- =========================================================
-- EXTENSIONS
-- =========================================================

create extension if not exists pgcrypto;
create extension if not exists pg_trgm;

-- Vector search preparation for future SBERT/pgvector work.
-- create extension if not exists vector;

-- =========================================================
-- RESTAURANTS
-- Internal master table. reviews.store_id should eventually map here.
-- =========================================================

create table if not exists restaurants (
  id text primary key,
  name text not null,
  category_name text,
  category_group_code text,
  category_group_name text,
  phone text,
  address_name text,
  road_address_name text,
  place_url text,
  lat double precision,
  lng double precision,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists restaurants_name_trgm_idx
  on restaurants using gin (name gin_trgm_ops);

create index if not exists restaurants_category_idx
  on restaurants (category_group_name);

-- =========================================================
-- RESTAURANT PLACE MAPPINGS
-- Connects one internal restaurant to Kakao/Naver/etc place ids.
-- =========================================================

create table if not exists restaurant_place_mappings (
  restaurant_id text not null
    references restaurants(id) on delete cascade,
  source text not null check (
    source in ('kakao', 'naver', 'google', 'manual')
  ),
  external_place_id text not null,
  external_url text,
  raw_name text,
  raw_address text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (restaurant_id, source, external_place_id)
);

create index if not exists restaurant_place_mappings_source_external_idx
  on restaurant_place_mappings (source, external_place_id);

create index if not exists restaurant_place_mappings_restaurant_idx
  on restaurant_place_mappings (restaurant_id);

-- =========================================================
-- SEARCH ISSUE KEYWORDS
-- Situation/intent based chips.
-- =========================================================

create table if not exists search_issue_keywords (
  id text primary key,
  label text not null,
  keyword text not null,
  aliases text[] not null default '{}',
  review_keywords text[] not null default '{}',
  base_score integer not null default 25,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists search_issue_keywords_keyword_trgm_idx
  on search_issue_keywords using gin (keyword gin_trgm_ops);

-- =========================================================
-- RESTAURANT MENUS
-- restaurant_name is duplicated intentionally for current search_preview.py.
-- Later, search_preview.py can switch to restaurants join.
-- =========================================================

create table if not exists restaurant_menus (
  id uuid primary key default gen_random_uuid(),
  restaurant_id text not null
    references restaurants(id) on delete cascade,
  restaurant_name text not null,
  name text not null,
  price integer check (price is null or price >= 0),
  price_label text,
  image_url text,
  is_best boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists restaurant_menus_restaurant_id_idx
  on restaurant_menus (restaurant_id);

create index if not exists restaurant_menus_restaurant_name_trgm_idx
  on restaurant_menus using gin (restaurant_name gin_trgm_ops);

create index if not exists restaurant_menus_name_trgm_idx
  on restaurant_menus using gin (name gin_trgm_ops);

-- =========================================================
-- REVIEW KEYWORD STATS
-- MVP keyword-counting stats for issue-based ranking.
-- =========================================================

create table if not exists restaurant_review_keyword_stats (
  restaurant_id text not null
    references restaurants(id) on delete cascade,
  issue_keyword_id text not null
    references search_issue_keywords(id) on delete cascade,
  positive_count integer not null default 0
    check (positive_count >= 0),
  total_count integer not null default 0
    check (total_count >= 0),
  updated_at timestamptz not null default now(),
  primary key (restaurant_id, issue_keyword_id)
);

create index if not exists review_keyword_stats_issue_idx
  on restaurant_review_keyword_stats (issue_keyword_id);

-- =========================================================
-- USER SEARCH HISTORY
-- Saved when a logged-in user selects a result.
-- =========================================================

create table if not exists user_search_histories (
  id uuid primary key default gen_random_uuid(),
  user_email text not null,
  query text not null,
  clicked_type text not null check (
    clicked_type in ('menu', 'restaurant', 'issue', 'quick_preview')
  ),
  clicked_id text,
  clicked_label text,
  restaurant_id text
    references restaurants(id) on delete set null,
  menu_id uuid
    references restaurant_menus(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists user_search_histories_user_created_idx
  on user_search_histories (user_email, created_at desc);

create index if not exists user_search_histories_created_at_idx
  on user_search_histories (created_at);

create index if not exists user_search_histories_query_trgm_idx
  on user_search_histories using gin (query gin_trgm_ops);

-- Keep recent search history for 14 days.
-- Existing expired rows are removed once when this SQL is applied,
-- and future inserts trigger lightweight cleanup for that user.
delete from user_search_histories
where created_at < now() - interval '14 days';

create or replace function prune_user_search_histories(
  p_user_email text default null
)
returns void
language plpgsql
as $$
begin
  delete from user_search_histories
  where created_at < now() - interval '14 days'
    and (
      p_user_email is null
      or user_email = p_user_email
    );
end;
$$;

create or replace function trg_prune_expired_user_search_histories()
returns trigger
language plpgsql
as $$
begin
  perform prune_user_search_histories(new.user_email);
  return new;
end;
$$;

drop trigger if exists user_search_histories_prune_14d_trigger
on user_search_histories;

create trigger user_search_histories_prune_14d_trigger
after insert on user_search_histories
for each row
execute function trg_prune_expired_user_search_histories();

-- =========================================================
-- OPTIONAL: REVIEW EMBEDDING
-- Future pgvector + SBERT search.
-- =========================================================

-- alter table reviews
-- add column if not exists embedding vector(768);

-- =========================================================
-- OPTIONAL: REVIEW SUMMARY
-- LLM summary cache.
-- =========================================================

alter table reviews
add column if not exists review_summary text;

-- =========================================================
-- OPTIONAL: SEARCH SCORE CACHE
-- =========================================================

create table if not exists restaurant_search_scores (
  restaurant_id text primary key
    references restaurants(id) on delete cascade,
  score double precision not null default 0,
  updated_at timestamptz not null default now()
);

-- =========================================================
-- DEFAULT ISSUE KEYWORDS
-- =========================================================

insert into search_issue_keywords (
  id,
  label,
  keyword,
  aliases,
  review_keywords,
  base_score,
  is_active
) values
  (
    'sweet-dessert',
    '달콤한 디저트가 당길 때',
    '달콤',
    array['디저트', '당충전', '케이크', '라떼'],
    array['달콤', '달달', '케이크', '크림', '디저트', '라떼'],
    25,
    true
  ),
  (
    'spicy-relief',
    '매운맛으로 스트레스 풀고 싶을 때',
    '매운맛',
    array['매움', '얼큰', '마라', '불닭'],
    array['맵다', '매콤', '얼얼', '칼칼', '마라', '불맛'],
    25,
    true
  ),
  (
    'rainy-day',
    '비 오는 날 생각나는 메뉴',
    '비오는날',
    array['비', '전', '국물', '칼국수'],
    array['국물', '따뜻', '전', '칼국수', '수제비', '막걸리'],
    25,
    true
  ),
  (
    'hangover',
    '해장이 필요할 때',
    '해장',
    array['국밥', '라멘', '짬뽕', '쌀국수'],
    array['해장', '얼큰', '국물', '든든', '속풀이'],
    25,
    true
  ),
  (
    'healthy-light',
    '가볍고 건강하게 먹고 싶을 때',
    '건강식',
    array['샐러드', '포케', '저칼로리'],
    array['신선', '가볍', '샐러드', '포케', '담백'],
    25,
    true
  ),
  (
    'date-night',
    '데이트하기 좋은 분위기',
    '데이트',
    array['분위기', '와인', '파스타'],
    array['분위기', '조용', '와인', '파스타', '기념일'],
    25,
    true
  ),
  (
    'late-night',
    '늦은 시간 든든하게 먹고 싶을 때',
    '야식',
    array['심야', '술안주', '치킨'],
    array['야식', '늦게', '술안주', '치킨', '튀김'],
    25,
    true
  ),
  (
    'study-cafe',
    '오래 머물기 좋은 카페',
    '카공',
    array['공부', '콘센트', '조용한카페'],
    array['콘센트', '조용', '넓다', '좌석', '카공'],
    25,
    true
  )
on conflict (id) do update set
  label = excluded.label,
  keyword = excluded.keyword,
  aliases = excluded.aliases,
  review_keywords = excluded.review_keywords,
  base_score = excluded.base_score,
  is_active = excluded.is_active,
  updated_at = now();

-- =========================================================
-- OPTIONAL: SAMPLE DATA FOR API TESTING
-- Uncomment only when you need smoke-test rows.
-- =========================================================

-- insert into restaurants (id, name, category_group_name)
-- values
--   ('REST_1', '돌체 베이커리', '카페'),
--   ('REST_2', '스타벅스 수원광교점', '카페')
-- on conflict (id) do update set
--   name = excluded.name,
--   category_group_name = excluded.category_group_name,
--   updated_at = now();

-- insert into restaurant_place_mappings (
--   restaurant_id,
--   source,
--   external_place_id,
--   raw_name
-- ) values
--   ('REST_1', 'kakao', '123456', '돌체 베이커리'),
--   ('REST_1', 'naver', '998877', '돌체 베이커리')
-- on conflict (restaurant_id, source, external_place_id) do update set
--   raw_name = excluded.raw_name,
--   updated_at = now();

-- insert into restaurant_menus (
--   restaurant_id,
--   restaurant_name,
--   name,
--   price,
--   price_label,
--   image_url,
--   is_best
-- ) values
--   ('REST_1', '돌체 베이커리', '돌체 휘낭시에', 4500, null, null, true),
--   ('REST_2', '스타벅스 수원광교점', '돌체라떼', 5900, null, null, true);
