-- =========================================================
-- Search MVP test seed data
--
-- Base location:
--   Gwanggyo Jungang Station
--   lat: 37.2883843017536
--   lng: 127.051726324729
--
-- Source:
--   Kakao Local API keyword search
--
-- Notes:
--   - Starbucks rows are from a 5km radius around Gwanggyo.
--   - Blue Bottle has no result within 5km, so the nearest Pangyo rows use a 20km radius.
--   - Kakao does not provide menu/price data. restaurant_menus below are test data
--     for validating the current /api/search/preview behavior.
-- =========================================================

-- Optional duplicate guard for external place ids.
-- This allows REST_KAKAO_27122533 / kakao / 27122533 and
-- REST_NAVER_27122533 / naver / 27122533 at the same time,
-- but prevents the same Kakao id from being mapped to multiple restaurants.
create unique index if not exists restaurant_place_mappings_source_external_unique
on restaurant_place_mappings (source, external_place_id);

-- =========================================================
-- RESTAURANTS
-- =========================================================

insert into restaurants (
  id,
  name,
  category_name,
  category_group_code,
  category_group_name,
  phone,
  address_name,
  road_address_name,
  place_url,
  lat,
  lng
)
values
  (
    'REST_KAKAO_27122533',
    '스타벅스 수원광교점',
    '음식점 > 카페 > 커피전문점 > 스타벅스',
    'CE7',
    '카페',
    '1522-3232',
    '경기 수원시 영통구 이의동 1332',
    '경기 수원시 영통구 센트럴타운로 85',
    'http://place.map.kakao.com/27122533',
    37.290239487654574,
    127.04974501198542
  ),
  (
    'REST_KAKAO_475924484',
    '스타벅스 광교엘포트R점',
    '음식점 > 카페 > 커피전문점 > 스타벅스',
    'CE7',
    '카페',
    '1522-3232',
    '경기 수원시 영통구 이의동 1336-1',
    '경기 수원시 영통구 광교중앙로 145',
    'http://place.map.kakao.com/475924484',
    37.286837089726056,
    127.05784528379459
  ),
  (
    'REST_KAKAO_1626776480',
    '스타벅스 광교갤러리아6F점',
    '음식점 > 카페 > 커피전문점 > 스타벅스',
    'CE7',
    '카페',
    '1522-3232',
    '경기 수원시 영통구 하동 1017-2',
    '경기 수원시 영통구 광교중앙로 124',
    'http://place.map.kakao.com/1626776480',
    37.2852804731374,
    127.057065996574
  ),
  (
    'REST_KAKAO_1745021441',
    '스타벅스 광교갤러리아9F점',
    '음식점 > 카페 > 커피전문점 > 스타벅스',
    'CE7',
    '카페',
    '1522-3232',
    '경기 수원시 영통구 하동 1017-3',
    '경기 수원시 영통구 광교호수공원로 320',
    'http://place.map.kakao.com/1745021441',
    37.28471260985939,
    127.05749746404253
  ),
  (
    'REST_KAKAO_722895269',
    '스타벅스 광교SK뷰레이크41F점',
    '음식점 > 카페 > 커피전문점 > 스타벅스',
    'CE7',
    '카페',
    '1522-3232',
    '경기 수원시 영통구 하동 1016-1',
    '경기 수원시 영통구 법조로 25',
    'http://place.map.kakao.com/722895269',
    37.28693673022635,
    127.0603995998129
  ),
  (
    'REST_KAKAO_53296991',
    '블루보틀 판교현대카페',
    '음식점 > 카페 > 커피전문점 > 블루보틀',
    'CE7',
    '카페',
    '1533-6906',
    '경기 성남시 분당구 백현동 541',
    '경기 성남시 분당구 판교역로146번길 20',
    'http://place.map.kakao.com/53296991',
    37.39324775042114,
    127.1119849434118
  ),
  (
    'REST_KAKAO_743101177',
    '블루보틀 판교카페',
    '음식점 > 카페 > 커피전문점 > 블루보틀',
    'CE7',
    '카페',
    '1533-6906',
    '경기 성남시 분당구 삼평동 740',
    '경기 성남시 분당구 동판교로177번길 25',
    'http://place.map.kakao.com/743101177',
    37.396710927155794,
    127.11329900304756
  )
on conflict (id)
do update set
  name = excluded.name,
  category_name = excluded.category_name,
  category_group_code = excluded.category_group_code,
  category_group_name = excluded.category_group_name,
  phone = excluded.phone,
  address_name = excluded.address_name,
  road_address_name = excluded.road_address_name,
  place_url = excluded.place_url,
  lat = excluded.lat,
  lng = excluded.lng,
  updated_at = now();

-- =========================================================
-- PLACE MAPPINGS
-- =========================================================

insert into restaurant_place_mappings (
  restaurant_id,
  source,
  external_place_id,
  external_url,
  raw_name,
  raw_address
)
values
  (
    'REST_KAKAO_27122533',
    'kakao',
    '27122533',
    'http://place.map.kakao.com/27122533',
    '스타벅스 수원광교점',
    '경기 수원시 영통구 센트럴타운로 85'
  ),
  (
    'REST_KAKAO_475924484',
    'kakao',
    '475924484',
    'http://place.map.kakao.com/475924484',
    '스타벅스 광교엘포트R점',
    '경기 수원시 영통구 광교중앙로 145'
  ),
  (
    'REST_KAKAO_1626776480',
    'kakao',
    '1626776480',
    'http://place.map.kakao.com/1626776480',
    '스타벅스 광교갤러리아6F점',
    '경기 수원시 영통구 광교중앙로 124'
  ),
  (
    'REST_KAKAO_1745021441',
    'kakao',
    '1745021441',
    'http://place.map.kakao.com/1745021441',
    '스타벅스 광교갤러리아9F점',
    '경기 수원시 영통구 광교호수공원로 320'
  ),
  (
    'REST_KAKAO_722895269',
    'kakao',
    '722895269',
    'http://place.map.kakao.com/722895269',
    '스타벅스 광교SK뷰레이크41F점',
    '경기 수원시 영통구 법조로 25'
  ),
  (
    'REST_KAKAO_53296991',
    'kakao',
    '53296991',
    'http://place.map.kakao.com/53296991',
    '블루보틀 판교현대카페',
    '경기 성남시 분당구 판교역로146번길 20'
  ),
  (
    'REST_KAKAO_743101177',
    'kakao',
    '743101177',
    'http://place.map.kakao.com/743101177',
    '블루보틀 판교카페',
    '경기 성남시 분당구 동판교로177번길 25'
  )
on conflict (source, external_place_id)
do update set
  restaurant_id = excluded.restaurant_id,
  external_url = excluded.external_url,
  raw_name = excluded.raw_name,
  raw_address = excluded.raw_address,
  updated_at = now();

-- =========================================================
-- TEST MENUS
-- Current search_preview.py searches restaurant_menus.name.
-- Brand keywords are included in a few test menu names so that
-- "스타벅스" and "블루보틀" can be tested before restaurant-name search lands.
-- =========================================================

insert into restaurant_menus (
  id,
  restaurant_id,
  restaurant_name,
  name,
  price,
  price_label,
  image_url,
  is_best
)
values
  (
    '10000000-0000-0000-0000-000000000001',
    'REST_KAKAO_27122533',
    '스타벅스 수원광교점',
    '돌체라떼',
    5900,
    null,
    null,
    true
  ),
  (
    '10000000-0000-0000-0000-000000000002',
    'REST_KAKAO_27122533',
    '스타벅스 수원광교점',
    '스타벅스 돌체라떼',
    5900,
    null,
    null,
    true
  ),
  (
    '10000000-0000-0000-0000-000000000003',
    'REST_KAKAO_475924484',
    '스타벅스 광교엘포트R점',
    '아이스 돌체라떼',
    5900,
    null,
    null,
    true
  ),
  (
    '10000000-0000-0000-0000-000000000004',
    'REST_KAKAO_1626776480',
    '스타벅스 광교갤러리아6F점',
    '돌체 콜드브루',
    6100,
    null,
    null,
    true
  ),
  (
    '10000000-0000-0000-0000-000000000005',
    'REST_KAKAO_53296991',
    '블루보틀 판교현대카페',
    '블루보틀 라떼',
    null,
    '가격 문의',
    null,
    true
  ),
  (
    '10000000-0000-0000-0000-000000000006',
    'REST_KAKAO_53296991',
    '블루보틀 판교현대카페',
    '시그니처 커피 메뉴',
    null,
    '가격 문의',
    null,
    true
  ),
  (
    '10000000-0000-0000-0000-000000000007',
    'REST_KAKAO_743101177',
    '블루보틀 판교카페',
    '블루보틀 콜드브루',
    null,
    '가격 문의',
    null,
    true
  ),
  (
    '10000000-0000-0000-0000-000000000101',
    'REST_KAKAO_26624127',
    '커피빈 광교아브뉴프랑점',
    '아메리카노',
    null,
    '가격 문의',
    null,
    true
  ),
  (
    '10000000-0000-0000-0000-000000000102',
    'REST_KAKAO_26624127',
    '커피빈 광교아브뉴프랑점',
    '카페라테',
    null,
    '가격 문의',
    null,
    true
  ),
  (
    '10000000-0000-0000-0000-000000000103',
    'REST_KAKAO_26624127',
    '커피빈 광교아브뉴프랑점',
    '카라멜마끼아또',
    null,
    '가격 문의',
    null,
    true
  )
on conflict (id)
do update set
  restaurant_id = excluded.restaurant_id,
  restaurant_name = excluded.restaurant_name,
  name = excluded.name,
  price = excluded.price,
  price_label = excluded.price_label,
  image_url = excluded.image_url,
  is_best = excluded.is_best,
  updated_at = now();

-- =========================================================
-- LIGHTWEIGHT REVIEW KEYWORD STATS FOR ISSUE CHIPS
-- =========================================================

insert into restaurant_review_keyword_stats (
  restaurant_id,
  issue_keyword_id,
  positive_count,
  total_count
)
values
  ('REST_KAKAO_27122533', 'sweet-dessert', 12, 18),
  ('REST_KAKAO_475924484', 'sweet-dessert', 8, 12),
  ('REST_KAKAO_1626776480', 'sweet-dessert', 6, 10),
  ('REST_KAKAO_53296991', 'study-cafe', 7, 9),
  ('REST_KAKAO_743101177', 'study-cafe', 5, 8)
on conflict (restaurant_id, issue_keyword_id)
do update set
  positive_count = excluded.positive_count,
  total_count = excluded.total_count,
  updated_at = now();
