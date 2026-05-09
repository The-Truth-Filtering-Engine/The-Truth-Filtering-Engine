-- ════════════════════════════════════════════════════════
-- Supabase SQL Editor에 순서대로 실행하세요
-- ════════════════════════════════════════════════════════

-- 1. reviews (검색 시 자동 저장됨)
create table if not exists reviews (
  id                   uuid primary key default gen_random_uuid(),
  query                text not null,
  review_title         text,
  review_description   text,
  review_bloggername   text,
  review_bloggerlink   text,
  review_link          text,
  review_postdate      text,
  is_ad_electra_pred   boolean,
  is_ad_finetuned_pred float8,
  is_ad_llm_pred       float8,
  created_at           timestamptz default now(),
  unique (query, review_link)   -- 중복 방지
);

-- 2. 신고
create table if not exists review_reports (
  id          uuid primary key default gen_random_uuid(),
  review_id   uuid references reviews(id) on delete cascade,
  reason      text not null,
  detail      text,
  reporter_id uuid references auth.users(id),
  status      text default 'pending',
  created_at  timestamptz default now()
);

-- 3. 신뢰도 투표
create table if not exists review_votes (
  id         uuid primary key default gen_random_uuid(),
  review_id  uuid references reviews(id) on delete cascade,
  vote       text not null check (vote in ('trust', 'doubt')),
  user_id    uuid references auth.users(id),
  created_at timestamptz default now()
);

-- 4. AI 피드백
create table if not exists ai_feedbacks (
  id              uuid primary key default gen_random_uuid(),
  review_id       uuid references reviews(id) on delete cascade,
  ai_was_correct  boolean not null,
  user_label      text check (user_label in ('ad', 'not_ad')),
  user_id         uuid references auth.users(id),
  created_at      timestamptz default now()
);

-- 5. 태그
create table if not exists review_tags (
  id         uuid primary key default gen_random_uuid(),
  review_id  uuid references reviews(id) on delete cascade,
  tag        text not null,
  user_id    uuid references auth.users(id),
  created_at timestamptz default now()
);

-- ────────────────────────────────────────────────────────
-- 인덱스 (조회 성능)
-- ────────────────────────────────────────────────────────
create index if not exists idx_reviews_query        on reviews(query);
create index if not exists idx_review_reports_rid   on review_reports(review_id);
create index if not exists idx_review_votes_rid     on review_votes(review_id);
create index if not exists idx_ai_feedbacks_rid     on ai_feedbacks(review_id);
create index if not exists idx_review_tags_rid      on review_tags(review_id);