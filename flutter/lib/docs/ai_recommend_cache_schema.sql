-- =========================================================
-- AI recommendation external API cache schema.
--
-- Goal:
-- - Reduce Kakao API calls from AI recommendation.
-- - Cache location text -> region.
-- - Cache coordinate -> region.
-- - Cache restaurant/place name -> Kakao place.
--
-- Apply after search_schema.sql.
-- =========================================================

create extension if not exists pgcrypto;
create extension if not exists pg_trgm;

-- =========================================================
-- NORMALIZATION HELPERS
-- =========================================================

create or replace function normalize_search_text(value text)
returns text
language sql
immutable
as $$
  select lower(regexp_replace(trim(coalesce(value, '')), '\s+', '', 'g'));
$$;

-- =========================================================
-- LOCATION QUERY CACHE
-- "부산 해운대", "제주 애월" 같은 입력 위치를 캐싱.
-- Kakao address/keyword search + coord2region 호출을 줄이는 목적.
-- =========================================================

create table if not exists location_query_cache (
  query_norm text primary key,
  query_text text not null,

  source text not null default 'kakao' check (
    source in ('kakao_address', 'kakao_keyword', 'manual', 'unknown')
  ),

  external_place_id text,
  external_place_name text,
  address_name text,
  road_address_name text,
  lat double precision,
  lng double precision,

  si text not null default '',
  gu text not null default '',
  dong text not null default '',
  legal_dong text not null default '',
  region_label text not null default '',

  hit_count integer not null default 0 check (hit_count >= 0),
  last_used_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '90 days'),
  raw_payload jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists location_query_cache_query_text_trgm_idx
  on location_query_cache using gin (query_text gin_trgm_ops);

create index if not exists location_query_cache_region_idx
  on location_query_cache (si, gu, dong);

create index if not exists location_query_cache_expires_idx
  on location_query_cache (expires_at);

-- =========================================================
-- COORDINATE REGION CACHE
-- 지도 선택/현재 위치 좌표를 행정구역으로 바꾸는 결과 캐싱.
-- grid_key는 앱/백엔드에서 소수 4자리 정도로 반올림해서 생성 권장.
-- 예: 37.5142:127.0490
-- =========================================================

create table if not exists coordinate_region_cache (
  grid_key text primary key,

  center_lat double precision not null,
  center_lng double precision not null,

  si text not null default '',
  gu text not null default '',
  dong text not null default '',
  legal_dong text not null default '',
  region_label text not null default '',

  hit_count integer not null default 0 check (hit_count >= 0),
  last_used_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '90 days'),
  raw_payload jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists coordinate_region_cache_region_idx
  on coordinate_region_cache (si, gu, dong);

create index if not exists coordinate_region_cache_expires_idx
  on coordinate_region_cache (expires_at);

-- =========================================================
-- PLACE LOOKUP CACHE
-- AI 추천 리뷰의 식당명 -> Kakao place 검색 결과 캐싱.
-- _find_places_by_names()에서 같은 가게명을 반복 호출하지 않게 함.
-- =========================================================

create table if not exists place_lookup_cache (
  place_name_norm text primary key,
  requested_name text not null,

  source text not null default 'kakao' check (
    source in ('kakao', 'naver', 'manual', 'unknown')
  ),
  external_place_id text,
  external_place_name text,

  category_name text,
  category_group_code text,
  category_group_name text,
  phone text,
  address_name text,
  road_address_name text,
  place_url text,
  lat double precision,
  lng double precision,

  hit_count integer not null default 0 check (hit_count >= 0),
  last_used_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '90 days'),
  raw_payload jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists place_lookup_cache_requested_name_trgm_idx
  on place_lookup_cache using gin (requested_name gin_trgm_ops);

create index if not exists place_lookup_cache_external_idx
  on place_lookup_cache (source, external_place_id);

create index if not exists place_lookup_cache_expires_idx
  on place_lookup_cache (expires_at);

-- =========================================================
-- API CALL LOG
-- Optional quota/usage monitoring.
-- Backend can insert one row only when it actually calls Kakao/Naver.
-- =========================================================

create table if not exists external_api_call_logs (
  id uuid primary key default gen_random_uuid(),
  provider text not null check (provider in ('kakao', 'naver', 'google')),
  endpoint text not null,
  cache_key text,
  status_code integer,
  called_at timestamptz not null default now()
);

create index if not exists external_api_call_logs_provider_called_idx
  on external_api_call_logs (provider, called_at desc);

create index if not exists external_api_call_logs_cache_key_idx
  on external_api_call_logs (cache_key);

-- =========================================================
-- CLEANUP
-- Run manually, from pg_cron, or from backend maintenance.
-- =========================================================

create or replace function cleanup_expired_external_api_cache()
returns void
language sql
as $$
  delete from location_query_cache where expires_at < now();
  delete from coordinate_region_cache where expires_at < now();
  delete from place_lookup_cache where expires_at < now();
$$;

-- =========================================================
-- UPSERT EXAMPLES
-- Backend should use the same conflict keys.
-- =========================================================

-- location_query_cache:
-- on conflict (query_norm) do update set
--   hit_count = location_query_cache.hit_count + 1,
--   last_used_at = now(),
--   expires_at = now() + interval '90 days',
--   updated_at = now();

-- coordinate_region_cache:
-- on conflict (grid_key) do update set
--   hit_count = coordinate_region_cache.hit_count + 1,
--   last_used_at = now(),
--   expires_at = now() + interval '90 days',
--   updated_at = now();

-- place_lookup_cache:
-- on conflict (place_name_norm) do update set
--   hit_count = place_lookup_cache.hit_count + 1,
--   last_used_at = now(),
--   expires_at = now() + interval '90 days',
--   updated_at = now();
