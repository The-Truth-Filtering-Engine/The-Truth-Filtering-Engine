import {
  AlertCircle,
  ArrowLeft,
  Bookmark,
  BookmarkCheck,
  Clock,
  Coins,
  Crown,
  ExternalLink,
  Info,
  LocateFixed,
  LoaderCircle,
  LogOut,
  MapPin,
  Navigation,
  Phone,
  RefreshCw,
  Search,
  Settings,
  Share2,
  Sparkles,
  UserRound,
  X,
} from 'lucide-react'
import { createClient, type Session } from '@supabase/supabase-js'
import { type FormEvent, useEffect, useRef, useState } from 'react'
import appLogoUrl from '../logo.png'

type LoadState = 'loading' | 'ready' | 'error'

type MapPoint = {
  latitude: number
  longitude: number
}

type Restaurant = {
  id: string
  storeId: string
  name: string
  address: string
  category: string
  categoryName: string
  categoryGroupCode: string
  categoryGroupName: string
  distance: number
  phone: string
  link: string
  addressName: string
  roadAddressName: string
  placeUrl: string
  imageUrl: string
  latitude: number
  longitude: number
}

type DetailState = 'idle' | 'loading' | 'analyzing' | 'loaded' | 'noData' | 'error'

type ReviewGrade = 'real' | 'suspicious' | 'ad'

type BlogReview = {
  id: number
  title: string
  author: string
  date: string
  preview: string
  url: string
  adScore: number | null
  adProbability: number
  grade: ReviewGrade
}

type DetailData = {
  reviews: BlogReview[]
  keywords: Array<{ word: string; count: number }>
}

type AnalysisUsage = {
  charged?: boolean
  chargedBy?: 'freecount' | 'premiumcount' | 'coin' | null
  profile?: Record<string, unknown> | null
}

type DetailJson = {
  reviews?: Record<string, unknown>[]
  hasMore?: boolean
  usage?: AnalysisUsage
}

type AiRecommendItem = {
  id: number
  name: string
  reviewTitle: string
  reviewDescription: string
  reviewUrl: string
  bloggerName: string
  postDate: string
  adScore: number
  placeId: string
  placeName: string
  address: string
  category: string
  categoryGroupCode: string
  categoryGroupName: string
  addressName: string
  roadAddressName: string
  latitude: number | null
  longitude: number | null
  placeUrl: string
  phone: string
  imageUrl?: string
}

type AiRecommendState = {
  items: AiRecommendItem[]
  page: number
  hasNext: boolean
  isLoading: boolean
  errorMessage: string
  hasLoaded: boolean
  regionLabel: string
  currentRegionLabel: string
  currentRegionSi: string
  currentRegionGu: string
  currentRegionDong: string
  isRegionFiltered: boolean
}

type AiRegionScope = 'dong' | 'gu' | 'si'

type ActiveSidePanel =
  | 'search'
  | 'restaurant'
  | 'bookmarks'
  | 'recent'
  | 'detail'
  | 'ai'
  | 'settings'

type UserProfile = {
  email: string
  premium: number
  coin: number
  freecount: number
  premiumcount: number
  store: unknown
  bookmark: unknown
}

type UserBookmarks = {
  storeIds: string[]
  restaurants: Restaurant[]
}

type RecentAnalysisRestaurant = Omit<Restaurant, 'latitude' | 'longitude'> & {
  latitude: number | null
  longitude: number | null
}

type RecentAnalysisItem = {
  storeId: string
  analyzedDate: string
  daysElapsed: number | null
  remainingFreeDays: number
  restaurant: RecentAnalysisRestaurant
}

type RecentAnalyses = {
  today: string
  freeItems: RecentAnalysisItem[]
  expiredItems: RecentAnalysisItem[]
}

type RecentAnalysesState = {
  data: RecentAnalyses | null
  isLoading: boolean
  errorMessage: string
  hasLoaded: boolean
}

type UserProfileState = {
  profile: UserProfile | null
  isLoading: boolean
  isSaving: boolean
  errorMessage: string
  hasLoaded: boolean
}

type KakaoLatLng = {
  getLat: () => number
  getLng: () => number
}

type KakaoBounds = {
  getSouthWest: () => KakaoLatLng
  getNorthEast: () => KakaoLatLng
}

type KakaoLatLngBounds = {
  extend: (latLng: KakaoLatLng) => void
}

type KakaoMap = {
  getBounds: () => KakaoBounds
  getCenter: () => KakaoLatLng
  getLevel: () => number
  relayout: () => void
  setBounds: (bounds: KakaoLatLngBounds) => void
  setCenter: (latLng: KakaoLatLng) => void
  setLevel: (level: number) => void
}

type KakaoCustomOverlay = {
  setMap: (map: KakaoMap | null) => void
  setPosition: (latLng: KakaoLatLng) => void
}

type KakaoMaps = {
  LatLng: new (latitude: number, longitude: number) => KakaoLatLng
  LatLngBounds: new () => KakaoLatLngBounds
  Map: new (
    container: HTMLElement,
    options: { center: KakaoLatLng; level: number },
  ) => KakaoMap
  CustomOverlay: new (options: {
    content: HTMLElement
    position: KakaoLatLng
    xAnchor: number
    yAnchor: number
  }) => KakaoCustomOverlay
  event: {
    addListener: (target: KakaoMap, eventName: string, callback: () => void) => void
  }
  load: (callback: () => void) => void
}

declare global {
  interface Window {
    kakao?: {
      maps: KakaoMaps
    }
  }
}

const BACKEND_BASE_URL =
  import.meta.env.VITE_BACKEND_BASE_URL?.replace(/\/$/, '') ??
  'http://localhost:8000'
const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL?.trim() ?? ''
const SUPABASE_ANON_KEY = import.meta.env.VITE_SUPABASE_ANON_KEY?.trim() ?? ''
const GOOGLE_AUTH_REDIRECT_TO = 'https://truth-filtering-engine-web.vercel.app/'
const supabase =
  SUPABASE_URL && SUPABASE_ANON_KEY
    ? createClient(SUPABASE_URL, SUPABASE_ANON_KEY)
    : null
const KAKAO_SDK_ID = 'kakao-map-sdk'
const INITIAL_CENTER = { latitude: 37.5245, longitude: 127.037 }
const INITIAL_LEVEL = 4
const FOCUSED_LEVEL = 1
const VIEWPORT_DEBOUNCE_MS = 600
const REFRESH_DISTANCE_METERS = 150
const NEARBY_PLACE_DISPLAY_COUNT = 30
const SEARCH_RADIUS_METERS = 5000
const SEARCH_PLACE_DISPLAY_COUNT = 30
const REVIEW_BATCH_SIZE = 100
const REVIEW_PAGE_SIZE = 10
const MAX_REVIEW_RESULTS = 300
const ANALYSIS_FREE_WINDOW_DAYS = 2
const ANALYSIS_COIN_COST = 100
const DAY_IN_MS = 24 * 60 * 60 * 1000
const ANALYSIS_USAGE_REQUIRED_MESSAGE = '추가분석을 위해 코인을 충전해 주세요'
const BOOKMARK_STORAGE_KEY = 'bookmarked_restaurants'
const TEMP_ADMIN_AUTH_STORAGE_KEY = 'truth_filtering_temp_admin_auth'
const AI_REGION_SCOPE_LABELS: Record<AiRegionScope, string> = {
  si: '시',
  gu: '구',
  dong: '동',
}
const AI_REGION_SCOPE_OPTIONS: AiRegionScope[] = ['si', 'gu', 'dong']

let kakaoMapsLoader: Promise<KakaoMaps> | null = null

class ApiRequestError extends Error {
  status: number

  constructor(message: string, status: number) {
    super(message)
    this.name = 'ApiRequestError'
    this.status = status
  }
}

function isAnalysisUsageRequiredError(error: unknown) {
  return error instanceof ApiRequestError && error.status === 402
}

async function fetchKakaoJsKey() {
  const response = await fetch(`${BACKEND_BASE_URL}/config`)

  if (!response.ok) {
    throw new Error(`백엔드 설정 요청 실패: ${response.status}`)
  }

  const data = (await response.json()) as { kakaoJsKey?: string }
  const kakaoJsKey = data.kakaoJsKey?.trim()

  if (!kakaoJsKey) {
    throw new Error('백엔드 /config에 KAKAO_JS_KEY가 없습니다')
  }

  return kakaoJsKey
}

function loadKakaoMaps(kakaoJsKey: string) {
  if (kakaoMapsLoader) return kakaoMapsLoader

  kakaoMapsLoader = new Promise<KakaoMaps>((resolve, reject) => {
    const finishLoading = () => {
      const kakaoMaps = window.kakao?.maps

      if (!kakaoMaps) {
        reject(new Error('Kakao 지도 SDK를 찾을 수 없습니다'))
        return
      }

      kakaoMaps.load(() => resolve(kakaoMaps))
    }

    const existingScript = document.getElementById(KAKAO_SDK_ID)
    if (existingScript) {
      finishLoading()
      return
    }

    const script = document.createElement('script')
    script.id = KAKAO_SDK_ID
    script.async = true
    script.src = `https://dapi.kakao.com/v2/maps/sdk.js?appkey=${kakaoJsKey}&autoload=false`
    script.onload = finishLoading
    script.onerror = () => reject(new Error('Kakao 지도 SDK 로드 실패'))
    document.head.appendChild(script)
  })

  return kakaoMapsLoader
}

function getCurrentPosition() {
  return new Promise<GeolocationPosition>((resolve, reject) => {
    if (!navigator.geolocation) {
      reject(new Error('현재 브라우저에서 위치 정보를 사용할 수 없습니다'))
      return
    }

    navigator.geolocation.getCurrentPosition(resolve, reject, {
      enableHighAccuracy: true,
      maximumAge: 30_000,
      timeout: 10_000,
    })
  })
}

function createCurrentLocationMarker() {
  const outer = document.createElement('div')
  outer.className = 'current-location-marker'

  const inner = document.createElement('div')
  inner.className = 'current-location-dot'

  outer.appendChild(inner)
  return outer
}

function createRestaurantMarker(
  restaurant: Restaurant,
  onSelectRestaurant: (restaurant: Restaurant) => void,
) {
  const marker = document.createElement('button')
  marker.type = 'button'
  marker.className = 'restaurant-marker'
  marker.title = restaurant.name
  marker.textContent = isCafe(restaurant) ? '☕' : '🍽'
  marker.addEventListener('click', (event) => {
    event.preventDefault()
    event.stopPropagation()
    onSelectRestaurant(restaurant)
  })
  return marker
}

function isCafe(restaurant: Pick<Restaurant, 'category'>) {
  const normalizedCategory = restaurant.category.toLowerCase()
  return restaurant.category.includes('카페') || normalizedCategory.includes('cafe')
}

const CATEGORY_THUMBNAIL_BASE = '/images/thumbnails'

const CATEGORY_THUMBNAILS: Record<string, string> = {
  한식: 'korean',
  일식: 'japanese',
  중식: 'chinese',
  양식: 'western',
  패스트푸드: 'fastfood',
  분식: 'bunsik',
  카페: 'cafe',
  술집: 'bar',
  주점: 'bar',
  아시안: 'asian',
  '아시안/퓨전': 'asian',
  뷔페: 'buffet',
  치킨: 'chicken',
  피자: 'pizza',
  '고기/구이': 'meat',
  고기: 'meat',
  구이: 'meat',
  면: 'noodle',
  국수: 'noodle',
  해산물: 'seafood',
  횟집: 'seafood',
}

function primaryRestaurantCategory(
  restaurant: Pick<Restaurant, 'category' | 'categoryName' | 'categoryGroupName'>,
) {
  const rawCategory =
    restaurant.categoryName || restaurant.category || restaurant.categoryGroupName || ''
  const parts = rawCategory
    .split('>')
    .map((part) => part.trim())
    .filter(Boolean)

  if (parts[0] === '음식점' && parts[1]) return parts[1]
  return parts[1] || parts[0] || rawCategory.trim()
}

function restaurantThumbnailKey(
  restaurant: Pick<Restaurant, 'category' | 'categoryName' | 'categoryGroupName'>,
) {
  const primaryCategory = primaryRestaurantCategory(restaurant)
  if (CATEGORY_THUMBNAILS[primaryCategory]) {
    return CATEGORY_THUMBNAILS[primaryCategory]
  }

  const categoryText = [
    restaurant.category,
    restaurant.categoryName,
    restaurant.categoryGroupName,
  ].join(' ')

  if (/카페|커피/i.test(categoryText)) return 'cafe'
  if (/중식|중국|짜장|짬뽕/i.test(categoryText)) return 'chinese'
  if (/일식|일본|초밥|스시|돈까스/i.test(categoryText)) return 'japanese'
  if (/양식|파스타|스테이크/i.test(categoryText)) return 'western'
  if (/패스트푸드|버거|햄버거/i.test(categoryText)) return 'fastfood'
  if (/분식|떡볶이|김밥/i.test(categoryText)) return 'bunsik'
  if (/술집|주점|맥주|호프|와인/i.test(categoryText)) return 'bar'
  if (/아시안|퓨전|태국|베트남|쌀국수/i.test(categoryText)) return 'asian'
  if (/뷔페|부페/i.test(categoryText)) return 'buffet'
  if (/치킨/i.test(categoryText)) return 'chicken'
  if (/피자/i.test(categoryText)) return 'pizza'
  if (/고기|구이|갈비|삼겹/i.test(categoryText)) return 'meat'
  if (/면|국수|라멘|우동|냉면/i.test(categoryText)) return 'noodle'
  if (/해산물|횟집|회|생선|수산/i.test(categoryText)) return 'seafood'
  if (/한식|국밥|찌개|백반/i.test(categoryText)) return 'korean'
  return 'default'
}

function restaurantThumbnailSrc(
  restaurant: Pick<
    Restaurant,
    'category' | 'categoryName' | 'categoryGroupName' | 'imageUrl'
  >,
) {
  const imageUrl = cleanImageUrl(restaurant.imageUrl)
  if (imageUrl) return imageUrl

  return `${CATEGORY_THUMBNAIL_BASE}/${restaurantThumbnailKey(restaurant)}.png`
}

function RestaurantThumb({
  restaurant,
  className = '',
}: {
  restaurant: Pick<
    Restaurant,
    'category' | 'categoryName' | 'categoryGroupName' | 'imageUrl'
  >
  className?: string
}) {
  return (
    <img
      className={['restaurant-card-image', className].filter(Boolean).join(' ')}
      src={restaurantThumbnailSrc(restaurant)}
      alt=""
      aria-hidden="true"
      loading="lazy"
      draggable={false}
      onError={(event) => {
        if (!event.currentTarget.src.includes('/images/thumbnails/default.png')) {
          event.currentTarget.src = `${CATEGORY_THUMBNAIL_BASE}/default.png`
        }
      }}
    />
  )
}

function pointFromLatLng(latLng: KakaoLatLng): MapPoint {
  return {
    latitude: latLng.getLat(),
    longitude: latLng.getLng(),
  }
}

function distanceMeters(a: MapPoint, b: MapPoint) {
  const earthRadiusMeters = 6_371_000
  const lat1 = toRadians(a.latitude)
  const lat2 = toRadians(b.latitude)
  const dLat = toRadians(b.latitude - a.latitude)
  const dLng = toRadians(b.longitude - a.longitude)
  const h =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1) *
      Math.cos(lat2) *
      Math.sin(dLng / 2) *
      Math.sin(dLng / 2)
  const c = 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h))
  return earthRadiusMeters * c
}

function toRadians(degrees: number) {
  return (degrees * Math.PI) / 180
}

function calculateViewportRadius(map: KakaoMap) {
  const center = pointFromLatLng(map.getCenter())
  const bounds = map.getBounds()
  const southWest = pointFromLatLng(bounds.getSouthWest())
  const northEast = pointFromLatLng(bounds.getNorthEast())
  const northWest = {
    latitude: northEast.latitude,
    longitude: southWest.longitude,
  }
  const southEast = {
    latitude: southWest.latitude,
    longitude: northEast.longitude,
  }
  const radius = Math.floor(
    Math.max(
      distanceMeters(center, northWest),
      distanceMeters(center, southEast),
      distanceMeters(center, northEast),
      distanceMeters(center, southWest),
    ),
  )

  if (radius <= 0) return 0
  return Math.min(20_000, Math.max(100, radius))
}

async function fetchNearbyRestaurants(center: MapPoint, radius: number) {
  const params = new URLSearchParams({
    lat: center.latitude.toString(),
    lng: center.longitude.toString(),
    radius: radius.toString(),
    display: NEARBY_PLACE_DISPLAY_COUNT.toString(),
  })
  const response = await fetch(
    `${BACKEND_BASE_URL}/places/nearby-restaurants?${params.toString()}`,
  )

  if (!response.ok) {
    throw new Error(`주변 장소 요청 실패: ${response.status}`)
  }

  const data = (await response.json()) as {
      restaurants?: Array<{
        id?: string
        storeId?: string
        name?: string
        address?: string
        category?: string
        categoryName?: string
        categoryGroupCode?: string
        categoryGroupName?: string
        distance?: number | string
        phone?: string
        link?: string
        addressName?: string
        roadAddressName?: string
        placeUrl?: string
        imageUrl?: string
        lat?: number | string
        lng?: number | string
      }>
  }

  return (data.restaurants ?? [])
    .map(parseRestaurantPayloadItem)
    .filter(
      (restaurant) =>
        restaurant.id &&
        restaurant.name &&
        Number.isFinite(restaurant.latitude) &&
        Number.isFinite(restaurant.longitude) &&
        Number.isFinite(restaurant.distance),
    )
}

async function fetchSearchRestaurants(query: string, center: MapPoint) {
  const params = new URLSearchParams({
    query,
    lat: center.latitude.toString(),
    lng: center.longitude.toString(),
    radius: SEARCH_RADIUS_METERS.toString(),
    display: SEARCH_PLACE_DISPLAY_COUNT.toString(),
  })
  const response = await fetch(
    `${BACKEND_BASE_URL}/places/search-restaurants?${params.toString()}`,
  )

  if (!response.ok) {
    throw new Error(`검색 요청 실패: ${response.status}`)
  }

  const data = (await response.json()) as {
      restaurants?: Array<{
        id?: string
        storeId?: string
        name?: string
        address?: string
        category?: string
        categoryName?: string
        categoryGroupCode?: string
        categoryGroupName?: string
        distance?: number | string
        phone?: string
        link?: string
        addressName?: string
        roadAddressName?: string
        placeUrl?: string
        imageUrl?: string
        lat?: number | string
        lng?: number | string
      }>
  }

  return (data.restaurants ?? [])
    .map(parseRestaurantPayloadItem)
    .filter(
      (restaurant) =>
        restaurant.id &&
        restaurant.name &&
        Number.isFinite(restaurant.latitude) &&
        Number.isFinite(restaurant.longitude) &&
        Number.isFinite(restaurant.distance),
    )
}

function parseRestaurantPayloadItem(item: {
  id?: string
  storeId?: string
  name?: string
  address?: string
  category?: string
  categoryName?: string
  categoryGroupCode?: string
  categoryGroupName?: string
  distance?: number | string
  phone?: string
  link?: string
  addressName?: string
  roadAddressName?: string
  placeUrl?: string
  imageUrl?: string
  lat?: number | string
  lng?: number | string
}): Restaurant {
  const id = item.id?.toString() ?? ''
  const categoryName = item.categoryName?.toString() ?? item.category?.toString() ?? ''
  const placeUrl = (item.placeUrl ?? item.link)?.toString() ?? ''
  return {
    id,
    storeId: item.storeId?.toString() ?? id,
    name: item.name?.toString() ?? '',
    address: item.address?.toString() ?? '',
    category: (item.category?.toString() ?? categoryName) || '음식점',
    categoryName,
    categoryGroupCode: item.categoryGroupCode?.toString() ?? '',
    categoryGroupName: item.categoryGroupName?.toString() ?? '',
    distance: Number(item.distance ?? 0),
    phone: item.phone?.toString() ?? '',
    link: placeUrl,
    addressName: item.addressName?.toString() ?? '',
    roadAddressName: item.roadAddressName?.toString() ?? '',
    placeUrl,
    imageUrl: item.imageUrl?.toString() ?? '',
    latitude: Number(item.lat),
    longitude: Number(item.lng),
  }
}

function formatDistance(distance: number) {
  if (!Number.isFinite(distance) || distance <= 0) return '거리 정보 없음'
  if (distance >= 1000) return `${(distance / 1000).toFixed(1)}km`
  return `${Math.round(distance)}m`
}

function cleanText(value: unknown) {
  return String(value ?? '')
    .replace(/<[^>]*>/g, '')
    .replace(/&quot;/g, '"')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .trim()
}

function cleanExternalUrl(value: unknown) {
  const url = cleanText(value)
  return /^https?:\/\//i.test(url) ? url : ''
}

function cleanImageUrl(value: unknown) {
  const url = cleanText(value)
  return /^(https?:\/\/|\/)/i.test(url) ? url : ''
}

function formatReviewDate(value: unknown) {
  const raw = cleanText(value)
  if (/^\d{8}$/.test(raw)) {
    return `${raw.slice(0, 4)}.${raw.slice(4, 6)}.${raw.slice(6, 8)}`
  }
  return raw
}

function gradeFromScore(adScore: number | null): ReviewGrade {
  if (adScore === null) return 'suspicious'
  if (adScore >= 0.6) return 'ad'
  if (adScore >= 0.3) return 'suspicious'
  return 'real'
}

function gradeLabel(grade: ReviewGrade) {
  if (grade === 'real') return '진성'
  if (grade === 'ad') return '광고'
  return '의심'
}

function parseBlogReview(item: Record<string, unknown>): BlogReview {
  const electraPred =
    typeof item.is_ad_electra_pred === 'number' ? item.is_ad_electra_pred : null
  const scoreSource =
    typeof item.is_ad_finetuned_pred === 'number'
      ? item.is_ad_finetuned_pred
      : typeof item.is_ad_llm_pred === 'number'
        ? item.is_ad_llm_pred
        : electraPred === 1
          ? 0.9
          : electraPred === 0
            ? 0.1
            : null
  const adScore = scoreSource === null ? null : Math.max(0, Math.min(1, scoreSource))
  const description = cleanText(item.review_description)
  const preview = description
    ? description.length > 96
      ? `${description.slice(0, 96)}...`
      : description
    : '요약 없음'

  return {
    id: Number(item.id ?? 0),
    title: cleanText(item.review_title) || '(제목 없음)',
    author: cleanText(item.review_bloggername) || '알 수 없음',
    date: formatReviewDate(item.review_postdate),
    preview,
    url: cleanExternalUrl(item.review_url ?? item.reviewUrl ?? item.link),
    adScore,
    adProbability: adScore === null ? 50 : Math.round(adScore * 100),
    grade: gradeFromScore(adScore),
  }
}

function buildKeywords(reviews: BlogReview[]) {
  const stopWords = new Set([
    '맛집',
    '추천',
    '후기',
    '방문',
    '리뷰',
    '정말',
    '너무',
    '있는',
    '없는',
    '그리고',
    '에서',
    '으로',
    '하고',
    '까지',
    '강남',
    '카페',
  ])
  const counts = new Map<string, number>()

  for (const review of reviews) {
    const words = review.title
      .replace(/[^\p{L}\p{N}\s]/gu, ' ')
      .split(/\s+/)
      .map((word) => word.trim())
      .filter((word) => word.length >= 2 && !stopWords.has(word))

    for (const word of words) {
      counts.set(word, (counts.get(word) ?? 0) + 1)
    }
  }

  return [...counts.entries()]
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .slice(0, 14)
    .map(([word, count]) => ({ word, count }))
}

async function fetchDetailJson(
  path: string,
  signal: AbortSignal,
  accessToken?: string,
): Promise<DetailJson> {
  const response = await fetch(`${BACKEND_BASE_URL}${path}`, {
    signal,
    headers: accessToken
      ? {
          Authorization: `Bearer ${accessToken}`,
        }
      : undefined,
  })
  if (!response.ok) {
    throw new ApiRequestError(await readErrorMessage(response), response.status)
  }
  return (await response.json()) as DetailJson
}

function buildReviewSearchPath(
  endpoint: '/api/search' | '/api/search/cached',
  query: string,
  options: {
    mode?: string
    naverStart?: number
    refresh?: boolean
    limit?: number
    maxResults?: number
    restaurant?: Restaurant
  } = {},
) {
  const params = new URLSearchParams({
    query,
    limit: String(options.limit ?? REVIEW_BATCH_SIZE),
  })
  const restaurant = options.restaurant

  if (restaurant) {
    const storeId = restaurant.storeId || restaurant.id
    if (storeId) params.set('storeId', storeId)
    if (restaurant.categoryName) params.set('categoryName', restaurant.categoryName)
    if (restaurant.categoryGroupCode) {
      params.set('categoryGroupCode', restaurant.categoryGroupCode)
    }
    if (restaurant.categoryGroupName) {
      params.set('categoryGroupName', restaurant.categoryGroupName)
    }
    if (restaurant.phone) params.set('phone', restaurant.phone)
    if (restaurant.addressName) params.set('addressName', restaurant.addressName)
    if (restaurant.roadAddressName) {
      params.set('roadAddressName', restaurant.roadAddressName)
    }
    if (restaurant.placeUrl || restaurant.link) {
      params.set('placeUrl', restaurant.placeUrl || restaurant.link)
    }
  }

  if (endpoint === '/api/search') {
    params.set('mode', options.mode ?? 'model')
    params.set('naverStart', String(options.naverStart ?? 1))
    params.set('maxResults', String(options.maxResults ?? MAX_REVIEW_RESULTS))
    if (options.refresh) params.set('refresh', 'true')
  } else {
    params.set('limit', String(options.maxResults ?? MAX_REVIEW_RESULTS))
  }

  return `${endpoint}?${params.toString()}`
}

function mergeReviews(current: BlogReview[], incoming: BlogReview[]) {
  const byKey = new Map<string, BlogReview>()

  for (const review of current) {
    byKey.set(review.url || `id:${review.id}`, review)
  }
  for (const review of incoming) {
    byKey.set(review.url || `id:${review.id}`, review)
  }

  return [...byKey.values()]
}

function parseAiRecommendItem(item: Record<string, unknown>): AiRecommendItem {
  return {
    id: Number(item.id ?? 0),
    name: cleanText(item.name),
    reviewTitle: cleanText(item.reviewTitle),
    reviewDescription: cleanText(item.reviewDescription),
    reviewUrl: cleanText(item.reviewUrl),
    bloggerName: cleanText(item.bloggerName),
    postDate: formatReviewDate(item.postDate),
    adScore: Number(item.adScore ?? 0),
    placeId: cleanText(item.placeId),
    placeName: cleanText(item.placeName),
    address: cleanText(item.address),
    category: cleanText(item.category) || '음식점',
    categoryGroupCode: cleanText(item.categoryGroupCode),
    categoryGroupName: cleanText(item.categoryGroupName),
    addressName: cleanText(item.addressName),
    roadAddressName: cleanText(item.roadAddressName),
    latitude: Number.isFinite(Number(item.lat)) ? Number(item.lat) : null,
    longitude: Number.isFinite(Number(item.lng)) ? Number(item.lng) : null,
    placeUrl: cleanText(item.placeUrl),
    phone: cleanText(item.phone),
  }
}

function aiRecommendToRestaurant(item: AiRecommendItem): Restaurant | null {
  if (item.latitude === null || item.longitude === null) return null

  return {
    id: item.placeId || `review-${item.id}`,
    storeId: item.placeId,
    name: item.placeName || item.name || '이름 없는 장소',
    address: item.address,
    category: item.category || '음식점',
    categoryName: item.category,
    categoryGroupCode: item.categoryGroupCode,
    categoryGroupName: item.categoryGroupName,
    distance: 0,
    phone: item.phone,
    link: item.placeUrl,
    addressName: item.addressName,
    roadAddressName: item.roadAddressName,
    placeUrl: item.placeUrl,
    imageUrl: item.imageUrl ?? '',
    latitude: item.latitude,
    longitude: item.longitude,
  }
}

function formatAdScore(adScore: number) {
  if (!Number.isFinite(adScore)) return '정보 없음'
  return `${Math.round(Math.max(0, Math.min(1, adScore)) * 100)}%`
}

function parseProfileNumber(value: unknown) {
  const parsed = Number(value ?? 0)
  return Number.isFinite(parsed) ? parsed : 0
}

function parseUserProfile(item: Record<string, unknown>): UserProfile {
  return {
    email: cleanText(item.email),
    premium: parseProfileNumber(item.premium),
    coin: parseProfileNumber(item.coin),
    freecount: parseProfileNumber(item.freecount),
    premiumcount: parseProfileNumber(item.premiumcount),
    store: item.store ?? null,
    bookmark: item.bookmark ?? null,
  }
}

async function readErrorMessage(response: Response) {
  try {
    const data = (await response.json()) as { detail?: unknown }
    return cleanText(data.detail) || `요청 실패: ${response.status}`
  } catch {
    return `요청 실패: ${response.status}`
  }
}

async function fetchUserProfile(accessToken: string) {
  const response = await fetch(`${BACKEND_BASE_URL}/api/user/me`, {
    headers: {
      Authorization: `Bearer ${accessToken}`,
    },
  })

  if (!response.ok) {
    throw new Error(await readErrorMessage(response))
  }

  return parseUserProfile((await response.json()) as Record<string, unknown>)
}

async function updateUserPremium(accessToken: string, premium: boolean) {
  const response = await fetch(`${BACKEND_BASE_URL}/api/user/me/premium`, {
    method: 'PATCH',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ premium }),
  })

  if (!response.ok) {
    throw new Error(await readErrorMessage(response))
  }

  return parseUserProfile((await response.json()) as Record<string, unknown>)
}

async function chargeUserCoins(accessToken: string, amount: number) {
  const response = await fetch(`${BACKEND_BASE_URL}/api/user/me/coins`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ amount }),
  })

  if (!response.ok) {
    throw new Error(await readErrorMessage(response))
  }

  return parseUserProfile((await response.json()) as Record<string, unknown>)
}

function getRestaurantStoreId(restaurant: Pick<Restaurant, 'id' | 'storeId'>) {
  return restaurant.storeId?.trim() || restaurant.id.trim()
}

function getKoreaDateSerial(date = new Date()) {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Asia/Seoul',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date)

  const year = Number(parts.find((part) => part.type === 'year')?.value)
  const month = Number(parts.find((part) => part.type === 'month')?.value)
  const day = Number(parts.find((part) => part.type === 'day')?.value)

  if (!Number.isFinite(year) || !Number.isFinite(month) || !Number.isFinite(day)) {
    return null
  }

  return Math.floor(Date.UTC(year, month - 1, day) / DAY_IN_MS)
}

function parseStoreDateSerial(value: unknown) {
  const dateText = String(value ?? '').trim()
  if (!/^\d{8}$/.test(dateText)) return null

  const year = Number(dateText.slice(0, 4))
  const month = Number(dateText.slice(4, 6))
  const day = Number(dateText.slice(6, 8))
  if (!Number.isFinite(year) || !Number.isFinite(month) || !Number.isFinite(day)) {
    return null
  }

  return Math.floor(Date.UTC(year, month - 1, day) / DAY_IN_MS)
}

function getFreeDetailRemainingDays(
  restaurant: Restaurant,
  storeValue: unknown,
) {
  const storeId = getRestaurantStoreId(restaurant)
  if (!storeId || !storeValue || typeof storeValue !== 'object' || Array.isArray(storeValue)) {
    return null
  }

  const storedDateSerial = parseStoreDateSerial(
    (storeValue as Record<string, unknown>)[storeId],
  )
  const todaySerial = getKoreaDateSerial()
  if (storedDateSerial === null || todaySerial === null) return null

  const elapsedDays = Math.max(0, todaySerial - storedDateSerial)
  if (elapsedDays >= ANALYSIS_FREE_WINDOW_DAYS) return null

  return Math.max(
    1,
    ANALYSIS_FREE_WINDOW_DAYS - elapsedDays - 1,
  )
}

function getDetailUsageInfo(
  restaurant: Restaurant,
  profile: UserProfile | null,
) {
  if (!profile) {
    return {
      label: '상세 보기',
      canAnalyze: true,
    }
  }

  const remainingFreeDays = getFreeDetailRemainingDays(restaurant, profile.store)
  if (remainingFreeDays !== null) {
    return {
      label: `상세 보기 (무료-${remainingFreeDays}일 남음)`,
      canAnalyze: true,
    }
  }

  if (profile.freecount > 0 || profile.premiumcount > 0) {
    return {
      label: '상세 보기 (분석횟수 -1회)',
      canAnalyze: true,
    }
  }

  if (profile.coin >= ANALYSIS_COIN_COST) {
    return {
      label: `상세 보기 (-${ANALYSIS_COIN_COST} coin)`,
      canAnalyze: true,
    }
  }

  return {
    label: '상세 보기',
    canAnalyze: false,
  }
}

function getBookmarkStoreIds(restaurants: Restaurant[]) {
  const storeIds: string[] = []
  const seen = new Set<string>()

  for (const restaurant of restaurants) {
    const storeId = getRestaurantStoreId(restaurant)
    if (!storeId || seen.has(storeId)) continue
    seen.add(storeId)
    storeIds.push(storeId)
  }

  return storeIds
}

function dedupeBookmarkRestaurants(restaurants: Restaurant[]) {
  const seen = new Set<string>()
  const deduped: Restaurant[] = []

  for (const restaurant of restaurants) {
    const storeId = getRestaurantStoreId(restaurant)
    if (!storeId || seen.has(storeId)) continue
    seen.add(storeId)
    deduped.push(restaurant)
  }

  return deduped
}

function normalizeRestaurant(value: unknown): Restaurant | null {
  if (!value || typeof value !== 'object') return null

  const item = value as Record<string, unknown>
  const id = item.id?.toString() ?? ''
  const name = item.name?.toString() ?? ''
  const latitude = Number(item.latitude ?? item.lat)
  const longitude = Number(item.longitude ?? item.lng)

  if (!id || !name || !Number.isFinite(latitude) || !Number.isFinite(longitude)) {
    return null
  }

  return {
    id,
    storeId: item.storeId?.toString() ?? id,
    name,
    address: item.address?.toString() ?? '',
    category: item.category?.toString() ?? '음식점',
    categoryName: item.categoryName?.toString() ?? item.category?.toString() ?? '',
    categoryGroupCode: item.categoryGroupCode?.toString() ?? '',
    categoryGroupName: item.categoryGroupName?.toString() ?? '',
    distance: Number(item.distance ?? 0),
    phone: item.phone?.toString() ?? '',
    link: (item.link ?? item.placeUrl)?.toString() ?? '',
    addressName: item.addressName?.toString() ?? '',
    roadAddressName: item.roadAddressName?.toString() ?? '',
    placeUrl: (item.placeUrl ?? item.link)?.toString() ?? '',
    imageUrl: item.imageUrl?.toString() ?? '',
    latitude,
    longitude,
  }
}

function loadBookmarkedRestaurants() {
  try {
    const raw = window.localStorage.getItem(BOOKMARK_STORAGE_KEY)
    if (!raw) return []

    const decoded = JSON.parse(raw) as unknown
    if (!Array.isArray(decoded)) return []

    return dedupeBookmarkRestaurants(
      decoded
        .map((item) => normalizeRestaurant(item))
        .filter((restaurant): restaurant is Restaurant => Boolean(restaurant)),
    )
  } catch {
    return []
  }
}

function saveBookmarkedRestaurants(bookmarkedRestaurants: Restaurant[]) {
  window.localStorage.setItem(
    BOOKMARK_STORAGE_KEY,
    JSON.stringify(bookmarkedRestaurants),
  )
}

function parseBookmarkStoreMap(value: unknown) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    return {} as Record<string, Record<string, unknown>>
  }

  const storeMap: Record<string, Record<string, unknown>> = {}
  for (const [key, item] of Object.entries(value)) {
    const storeId = key.trim()
    if (!storeId || !item || typeof item !== 'object' || Array.isArray(item)) {
      continue
    }
    storeMap[storeId] = item as Record<string, unknown>
  }

  return storeMap
}

function parseUserBookmarks(item: Record<string, unknown>): UserBookmarks {
  const bookmarkMap = parseBookmarkStoreMap(item.bookmark)
  const storeIds = Object.keys(bookmarkMap)
  const restaurants = storeIds
    .map((storeId) =>
      normalizeRestaurant({
        ...(bookmarkMap[storeId] ?? {}),
        id: storeId,
        storeId,
      }),
    )
    .filter((restaurant): restaurant is Restaurant => Boolean(restaurant))

  return {
    storeIds,
    restaurants,
  }
}

function restaurantToBookmarkStore(restaurant: Restaurant) {
  const storeId = getRestaurantStoreId(restaurant)

  return {
    id: storeId,
    storeId,
    name: restaurant.name,
    address: restaurant.address,
    category: restaurant.category,
    categoryName: restaurant.categoryName,
    categoryGroupCode: restaurant.categoryGroupCode,
    categoryGroupName: restaurant.categoryGroupName,
    distance: restaurant.distance,
    phone: restaurant.phone,
    link: restaurant.link || restaurant.placeUrl,
    placeUrl: restaurant.placeUrl || restaurant.link,
    addressName: restaurant.addressName,
    roadAddressName: restaurant.roadAddressName,
    latitude: restaurant.latitude,
    longitude: restaurant.longitude,
    lat: restaurant.latitude,
    lng: restaurant.longitude,
  }
}

async function fetchUserBookmarks(accessToken: string) {
  const response = await fetch(`${BACKEND_BASE_URL}/api/user/me/bookmarks`, {
    headers: {
      Authorization: `Bearer ${accessToken}`,
    },
  })

  if (!response.ok) {
    throw new Error(await readErrorMessage(response))
  }

  return parseUserBookmarks((await response.json()) as Record<string, unknown>)
}

async function addUserBookmark(accessToken: string, restaurant: Restaurant) {
  const response = await fetch(`${BACKEND_BASE_URL}/api/user/me/bookmarks`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      storeId: getRestaurantStoreId(restaurant),
      store: restaurantToBookmarkStore(restaurant),
    }),
  })

  if (!response.ok) {
    throw new Error(await readErrorMessage(response))
  }

  return parseUserBookmarks((await response.json()) as Record<string, unknown>)
}

async function deleteUserBookmark(accessToken: string, storeId: string) {
  const response = await fetch(
    `${BACKEND_BASE_URL}/api/user/me/bookmarks/${encodeURIComponent(storeId)}`,
    {
      method: 'DELETE',
      headers: {
        Authorization: `Bearer ${accessToken}`,
      },
    },
  )

  if (!response.ok) {
    throw new Error(await readErrorMessage(response))
  }

  return parseUserBookmarks((await response.json()) as Record<string, unknown>)
}

function parseRecentAnalysisRestaurant(
  item: unknown,
  storeId: string,
): RecentAnalysisRestaurant {
  const source =
    item && typeof item === 'object' && !Array.isArray(item)
      ? (item as Record<string, unknown>)
      : {}
  const latitude = Number(source.latitude ?? source.lat)
  const longitude = Number(source.longitude ?? source.lng)
  const placeUrl = cleanText(source.placeUrl ?? source.link)

  return {
    id: cleanText(source.id) || storeId,
    storeId: cleanText(source.storeId) || storeId,
    name: cleanText(source.name) || storeId,
    address: cleanText(source.address),
    category: cleanText(source.category) || '음식점',
    categoryName: cleanText(source.categoryName),
    categoryGroupCode: cleanText(source.categoryGroupCode),
    categoryGroupName: cleanText(source.categoryGroupName),
    distance: Number(source.distance) || 0,
    phone: cleanText(source.phone),
    link: placeUrl,
    addressName: cleanText(source.addressName),
    roadAddressName: cleanText(source.roadAddressName),
    placeUrl,
    imageUrl: cleanText(source.imageUrl),
    latitude: Number.isFinite(latitude) ? latitude : null,
    longitude: Number.isFinite(longitude) ? longitude : null,
  }
}

function parseRecentAnalysisItem(item: Record<string, unknown>) {
  const storeId = cleanText(item.storeId)
  if (!storeId) return null

  const daysElapsed = Number(item.daysElapsed)
  return {
    storeId,
    analyzedDate: cleanText(item.analyzedDate),
    daysElapsed: Number.isFinite(daysElapsed) ? daysElapsed : null,
    remainingFreeDays: Number(item.remainingFreeDays) || 0,
    restaurant: parseRecentAnalysisRestaurant(item.restaurant, storeId),
  } satisfies RecentAnalysisItem
}

function parseRecentAnalyses(item: Record<string, unknown>): RecentAnalyses {
  const parseItems = (value: unknown) =>
    Array.isArray(value)
      ? value
          .map((entry) =>
            entry && typeof entry === 'object' && !Array.isArray(entry)
              ? parseRecentAnalysisItem(entry as Record<string, unknown>)
              : null,
          )
          .filter((entry): entry is RecentAnalysisItem => Boolean(entry))
      : []

  return {
    today: cleanText(item.today),
    freeItems: parseItems(item.freeItems),
    expiredItems: parseItems(item.expiredItems),
  }
}

function recentAnalysisToRestaurant(item: RecentAnalysisItem): Restaurant | null {
  const restaurant = item.restaurant
  if (
    typeof restaurant.latitude !== 'number' ||
    typeof restaurant.longitude !== 'number' ||
    !Number.isFinite(restaurant.latitude) ||
    !Number.isFinite(restaurant.longitude)
  ) {
    return null
  }

  return {
    ...restaurant,
    latitude: restaurant.latitude as number,
    longitude: restaurant.longitude as number,
  }
}

async function fetchRecentAnalyses(accessToken: string) {
  const response = await fetch(`${BACKEND_BASE_URL}/api/user/me/recent-analyses`, {
    headers: {
      Authorization: `Bearer ${accessToken}`,
    },
  })

  if (!response.ok) {
    throw new Error(await readErrorMessage(response))
  }

  return parseRecentAnalyses((await response.json()) as Record<string, unknown>)
}

function App() {
  const mapContainerRef = useRef<HTMLDivElement>(null)
  const kakaoMapsRef = useRef<KakaoMaps | null>(null)
  const kakaoMapRef = useRef<KakaoMap | null>(null)
  const currentLocationOverlayRef = useRef<KakaoCustomOverlay | null>(null)
  const restaurantOverlaysRef = useRef<KakaoCustomOverlay[]>([])
  const viewportRestaurantsRef = useRef<Restaurant[]>([])
  const searchModeRef = useRef(false)
  const bookmarkFocusModeRef = useRef(false)
  const searchRequestIdRef = useRef(0)
  const [loadState, setLoadState] = useState<LoadState>('loading')
  const [errorMessage, setErrorMessage] = useState('')
  const [placesErrorMessage, setPlacesErrorMessage] = useState('')
  const [selectedRestaurant, setSelectedRestaurant] = useState<Restaurant | null>(
    null,
  )
  const [bookmarkedRestaurants, setBookmarkedRestaurants] = useState<
    Restaurant[]
  >(() =>
    loadBookmarkedRestaurants(),
  )
  const [bookmarkedStoreIds, setBookmarkedStoreIds] = useState<string[]>(() =>
    getBookmarkStoreIds(loadBookmarkedRestaurants()),
  )
  const [activeSidePanel, setActiveSidePanel] = useState<ActiveSidePanel>(
    'search',
  )
  const [detailState, setDetailState] = useState<DetailState>('idle')
  const [detailData, setDetailData] = useState<DetailData | null>(null)
  const [detailErrorMessage, setDetailErrorMessage] = useState('')
  const [reviewSort, setReviewSort] = useState<'real' | 'latest'>('real')
  const [reviewPage, setReviewPage] = useState(0)
  const [detailHasMoreReviews, setDetailHasMoreReviews] = useState(false)
  const [isReviewBatchLoading, setIsReviewBatchLoading] = useState(false)
  const [currentPosition, setCurrentPosition] = useState<MapPoint | null>(null)
  const [searchInput, setSearchInput] = useState('')
  const [searchQuery, setSearchQuery] = useState('')
  const [searchResults, setSearchResults] = useState<Restaurant[]>([])
  const [searchState, setSearchState] = useState<
    'idle' | 'loading' | 'loaded' | 'error'
  >('idle')
  const [searchErrorMessage, setSearchErrorMessage] = useState('')
  const [authSession, setAuthSession] = useState<Session | null>(null)
  const [isTemporaryAdmin, setIsTemporaryAdmin] = useState(false)
  const [authStatus, setAuthStatus] = useState<
    'checking' | 'signedOut' | 'signedIn'
  >('checking')
  const [authErrorMessage, setAuthErrorMessage] = useState('')
  const [userProfileState, setUserProfileState] = useState<UserProfileState>({
    profile: null,
    isLoading: false,
    isSaving: false,
    errorMessage: '',
    hasLoaded: false,
  })
  const [aiRegionScope, setAiRegionScope] = useState<AiRegionScope>('si')
  const [aiRecommendState, setAiRecommendState] = useState<AiRecommendState>({
    items: [],
    page: 1,
    hasNext: false,
    isLoading: false,
    errorMessage: '',
    hasLoaded: false,
    regionLabel: '',
    currentRegionLabel: '',
    currentRegionSi: '',
    currentRegionGu: '',
    currentRegionDong: '',
    isRegionFiltered: false,
  })
  const [recentAnalysesState, setRecentAnalysesState] =
    useState<RecentAnalysesState>({
      data: null,
      isLoading: false,
      errorMessage: '',
      hasLoaded: false,
    })
  const [toastMessage, setToastMessage] = useState('')
  const isLoggedIn = authSession !== null || isTemporaryAdmin
  const bookmarkedIds = bookmarkedStoreIds
  const detailRequestIdRef = useRef(0)
  const reviewBatchRequestIdRef = useRef(0)
  const bookmarkSyncSessionRef = useRef<string | null>(null)

  function showToast(message: string) {
    setToastMessage(message)
    window.setTimeout(() => setToastMessage(''), 1800)
  }

  function resetUserProfileState() {
    setUserProfileState({
      profile: null,
      isLoading: false,
      isSaving: false,
      errorMessage: '',
      hasLoaded: false,
    })
  }

  function resetRecentAnalysesState() {
    setRecentAnalysesState({
      data: null,
      isLoading: false,
      errorMessage: '',
      hasLoaded: false,
    })
  }

  function applyRemoteBookmarkState(bookmarks: UserBookmarks) {
    setBookmarkedStoreIds(bookmarks.storeIds)
    setBookmarkedRestaurants(bookmarks.restaurants)
  }

  function applyLocalBookmarkState(restaurants: Restaurant[], shouldSave = false) {
    const nextRestaurants = dedupeBookmarkRestaurants(restaurants)
    setBookmarkedRestaurants(nextRestaurants)
    setBookmarkedStoreIds(getBookmarkStoreIds(nextRestaurants))
    if (shouldSave) {
      saveBookmarkedRestaurants(nextRestaurants)
    }
  }

  function applyUsageProfile(usage?: AnalysisUsage) {
    const profile = usage?.profile
    if (!profile) return

    setUserProfileState((previous) => ({
      ...previous,
      profile: parseUserProfile(profile),
      isLoading: false,
      isSaving: false,
      errorMessage: '',
      hasLoaded: true,
    }))
    setRecentAnalysesState((previous) => ({
      ...previous,
      hasLoaded: false,
    }))
  }

  useEffect(() => {
    setIsTemporaryAdmin(
      window.localStorage.getItem(TEMP_ADMIN_AUTH_STORAGE_KEY) === 'true',
    )

    if (!supabase) {
      setAuthStatus('signedOut')
      resetUserProfileState()
      resetRecentAnalysesState()
      return
    }

    let isMounted = true

    supabase.auth.getSession().then(({ data, error }) => {
      if (!isMounted) return

      if (error) {
        setAuthErrorMessage(error.message)
      }
      setAuthSession(data.session ?? null)
      setAuthStatus(data.session ? 'signedIn' : 'signedOut')
      if (!data.session) {
        resetUserProfileState()
        resetRecentAnalysesState()
      }
    })

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      setAuthSession(session)
      setAuthStatus(session ? 'signedIn' : 'signedOut')
      if (session) {
        setIsTemporaryAdmin(false)
        window.localStorage.removeItem(TEMP_ADMIN_AUTH_STORAGE_KEY)
      } else {
        resetUserProfileState()
        resetRecentAnalysesState()
      }
    })

    return () => {
      isMounted = false
      subscription.unsubscribe()
    }
  }, [])

  useEffect(() => {
    const token = authSession?.access_token

    if (!token) {
      if (isTemporaryAdmin) {
        applyLocalBookmarkState(loadBookmarkedRestaurants())
      }
      return
    }

    let canceled = false
    const accessToken = token
    const sessionKey = authSession.user?.id || token

    async function syncBookmarks() {
      try {
        let bookmarks = await fetchUserBookmarks(accessToken)
        const localBookmarks = loadBookmarkedRestaurants()

        if (
          localBookmarks.length > 0 &&
          bookmarkSyncSessionRef.current !== sessionKey
        ) {
          for (const restaurant of localBookmarks) {
            const storeId = getRestaurantStoreId(restaurant)
            const hasRemoteStore = bookmarks.restaurants.some(
              (item) => getRestaurantStoreId(item) === storeId,
            )
            if (
              !storeId ||
              (bookmarks.storeIds.includes(storeId) && hasRemoteStore)
            ) {
              continue
            }
            bookmarks = await addUserBookmark(accessToken, restaurant)
          }
          window.localStorage.removeItem(BOOKMARK_STORAGE_KEY)
        }

        bookmarkSyncSessionRef.current = sessionKey
        if (!canceled) {
          applyRemoteBookmarkState(bookmarks)
        }
      } catch (error) {
        if (canceled) return
        applyLocalBookmarkState(loadBookmarkedRestaurants())
        showToast(
          error instanceof Error
            ? `북마크 동기화 실패: ${error.message}`
            : '북마크 동기화에 실패했습니다',
        )
      }
    }

    void syncBookmarks()

    return () => {
      canceled = true
    }
  }, [authSession?.access_token, authSession?.user?.id, isTemporaryAdmin])

  async function signInWithGoogle() {
    if (!supabase) {
      setAuthErrorMessage(
        'Supabase 로그인 설정이 없습니다. VITE_SUPABASE_URL과 VITE_SUPABASE_ANON_KEY를 확인해 주세요.',
      )
      return
    }

    setAuthErrorMessage('')
    const { error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: GOOGLE_AUTH_REDIRECT_TO,
      },
    })

    if (error) {
      setAuthErrorMessage(error.message)
      showToast('Google 로그인을 시작하지 못했습니다')
    }
  }

  function signInAsTemporaryAdmin() {
    window.localStorage.setItem(TEMP_ADMIN_AUTH_STORAGE_KEY, 'true')
    setIsTemporaryAdmin(true)
    setAuthErrorMessage('')
    setAuthStatus('signedIn')
    resetUserProfileState()
    resetRecentAnalysesState()
    applyLocalBookmarkState(loadBookmarkedRestaurants())
    showToast('관리자 임시 로그인 상태입니다')
  }

  async function loadUserProfile() {
    const token = authSession?.access_token
    if (!token) {
      resetUserProfileState()
      return
    }

    setUserProfileState((previous) => ({
      ...previous,
      isLoading: true,
      errorMessage: '',
    }))

    try {
      const profile = await fetchUserProfile(token)
      setUserProfileState({
        profile,
        isLoading: false,
        isSaving: false,
        errorMessage: '',
        hasLoaded: true,
      })
    } catch (error) {
      setUserProfileState((previous) => ({
        ...previous,
        isLoading: false,
        isSaving: false,
        errorMessage:
          error instanceof Error
            ? error.message
            : '사용자 정보를 불러오지 못했습니다',
        hasLoaded: true,
      }))
    }
  }

  useEffect(() => {
    if (
      !authSession?.access_token ||
      userProfileState.hasLoaded ||
      userProfileState.isLoading ||
      userProfileState.errorMessage
    ) {
      return
    }

    void loadUserProfile()
  }, [
    authSession?.access_token,
    userProfileState.errorMessage,
    userProfileState.hasLoaded,
    userProfileState.isLoading,
  ])

  async function toggleUserPremium() {
    const token = authSession?.access_token
    const profile = userProfileState.profile
    if (!token || !profile) return

    setUserProfileState((previous) => ({
      ...previous,
      isSaving: true,
      errorMessage: '',
    }))

    try {
      const updated = await updateUserPremium(token, profile.premium !== 1)
      setUserProfileState({
        profile: updated,
        isLoading: false,
        isSaving: false,
        errorMessage: '',
        hasLoaded: true,
      })
      showToast(updated.premium === 1 ? '프리미엄이 설정되었습니다' : '프리미엄이 해제되었습니다')
    } catch (error) {
      setUserProfileState((previous) => ({
        ...previous,
        isSaving: false,
        errorMessage:
          error instanceof Error
            ? error.message
            : '프리미엄 상태를 변경하지 못했습니다',
      }))
    }
  }

  async function chargeCoins(amount: number) {
    const token = authSession?.access_token
    if (!token) return

    setUserProfileState((previous) => ({
      ...previous,
      isSaving: true,
      errorMessage: '',
    }))

    try {
      const updated = await chargeUserCoins(token, amount)
      setUserProfileState({
        profile: updated,
        isLoading: false,
        isSaving: false,
        errorMessage: '',
        hasLoaded: true,
      })
      showToast(`${amount.toLocaleString()} 코인이 충전되었습니다`)
    } catch (error) {
      setUserProfileState((previous) => ({
        ...previous,
        isSaving: false,
        errorMessage:
          error instanceof Error ? error.message : '코인을 충전하지 못했습니다',
      }))
    }
  }

  async function signOut() {
    try {
      if (supabase && authSession) {
        const { error } = await supabase.auth.signOut()
        if (error) throw error
      }

      window.localStorage.removeItem(TEMP_ADMIN_AUTH_STORAGE_KEY)
      setIsTemporaryAdmin(false)
      setAuthSession(null)
      setAuthStatus('signedOut')
      resetUserProfileState()
      resetRecentAnalysesState()
      setSelectedRestaurant(null)
      setActiveSidePanel('search')
      showToast('로그아웃되었습니다')
    } catch {
      showToast('로그아웃하지 못했습니다')
    }
  }

  async function copyToClipboard(value: string, successMessage: string) {
    try {
      await navigator.clipboard.writeText(value)
      showToast(successMessage)
    } catch {
      showToast('클립보드 복사에 실패했습니다')
    }
  }

  async function toggleBookmark(restaurant: Restaurant) {
    const storeId = getRestaurantStoreId(restaurant)
    if (!storeId) {
      showToast('북마크할 가게 ID가 없습니다')
      return
    }

    const bookmarked = bookmarkedStoreIds.includes(storeId)
    const previousRestaurants = bookmarkedRestaurants
    const previousStoreIds = bookmarkedStoreIds
    const nextRestaurants = bookmarked
      ? previousRestaurants.filter(
          (item) => getRestaurantStoreId(item) !== storeId,
        )
      : dedupeBookmarkRestaurants([
          restaurant,
          ...previousRestaurants.filter(
            (item) => getRestaurantStoreId(item) !== storeId,
          ),
        ])
    const nextStoreIds = bookmarked
      ? previousStoreIds.filter((item) => item !== storeId)
      : [storeId, ...previousStoreIds.filter((item) => item !== storeId)]

    setBookmarkedRestaurants(nextRestaurants)
    setBookmarkedStoreIds(nextStoreIds)

    const token = authSession?.access_token
    if (!token) {
      saveBookmarkedRestaurants(nextRestaurants)
      showToast(bookmarked ? '북마크에서 해제되었습니다' : '북마크에 저장했습니다')
      return
    }

    try {
      const bookmarks = bookmarked
        ? await deleteUserBookmark(token, storeId)
        : await addUserBookmark(token, restaurant)
      applyRemoteBookmarkState(bookmarks)
      showToast(bookmarked ? '북마크에서 해제되었습니다' : '북마크에 저장했습니다')
    } catch (error) {
      setBookmarkedRestaurants(previousRestaurants)
      setBookmarkedStoreIds(previousStoreIds)
      showToast(
        error instanceof Error
          ? `북마크 저장 실패: ${error.message}`
          : '북마크 저장에 실패했습니다',
      )
    }
  }

  function clearRestaurantOverlays() {
    for (const overlay of restaurantOverlaysRef.current) {
      overlay.setMap(null)
    }
    restaurantOverlaysRef.current = []
  }

  function displayRestaurantsOnMap(
    restaurants: Restaurant[],
    options: { preserveViewport?: boolean } = {},
  ) {
    if (!options.preserveViewport) {
      viewportRestaurantsRef.current =
        searchModeRef.current ? viewportRestaurantsRef.current : restaurants
    }

    const kakaoMaps = kakaoMapsRef.current
    const map = kakaoMapRef.current
    if (!kakaoMaps || !map) return

    clearRestaurantOverlays()
    restaurantOverlaysRef.current = restaurants.map((restaurant) => {
      const overlay = new kakaoMaps.CustomOverlay({
        content: createRestaurantMarker(restaurant, (selected) => {
          setSelectedRestaurant(selected)
          setActiveSidePanel('restaurant')
        }),
        position: new kakaoMaps.LatLng(
          restaurant.latitude,
          restaurant.longitude,
        ),
        xAnchor: 0.5,
        yAnchor: 0.5,
      })
      overlay.setMap(map)
      return overlay
    })
  }

  function fitMapToRestaurants(restaurants: Restaurant[]) {
    const kakaoMaps = kakaoMapsRef.current
    const map = kakaoMapRef.current
    if (!kakaoMaps || !map || restaurants.length === 0) return

    if (restaurants.length === 1) {
      map.setCenter(
        new kakaoMaps.LatLng(
          restaurants[0].latitude,
          restaurants[0].longitude,
        ),
      )
      map.setLevel(FOCUSED_LEVEL)
      return
    }

    const bounds = new kakaoMaps.LatLngBounds()
    for (const restaurant of restaurants) {
      bounds.extend(
        new kakaoMaps.LatLng(restaurant.latitude, restaurant.longitude),
      )
    }
    map.setBounds(bounds)
  }

  function getSearchCenter(): MapPoint {
    const map = kakaoMapRef.current
    if (map) return pointFromLatLng(map.getCenter())
    return currentPosition ?? INITIAL_CENTER
  }

  function clearRestaurantSearch() {
    searchRequestIdRef.current += 1
    searchModeRef.current = false
    bookmarkFocusModeRef.current = false
    setSearchInput('')
    setSearchQuery('')
    setSearchResults([])
    setSearchErrorMessage('')
    setSearchState('idle')
    setSelectedRestaurant(null)
    setActiveSidePanel('search')
    displayRestaurantsOnMap(viewportRestaurantsRef.current)
  }

  async function submitRestaurantSearch(event?: FormEvent<HTMLFormElement>) {
    event?.preventDefault()
    const query = searchInput.trim()
    if (!query) {
      showToast('검색어를 입력해 주세요')
      return
    }

    const requestId = ++searchRequestIdRef.current
    const center = getSearchCenter()
    searchModeRef.current = true
    bookmarkFocusModeRef.current = false
    setSelectedRestaurant(null)
    setActiveSidePanel('search')
    setSearchQuery(query)
    setSearchResults([])
    setSearchErrorMessage('')
    setSearchState('loading')
    displayRestaurantsOnMap([])

    try {
      const restaurants = await fetchSearchRestaurants(query, center)
      if (requestId !== searchRequestIdRef.current) return

      setSearchResults(restaurants)
      setSearchState('loaded')
      displayRestaurantsOnMap(restaurants)
      fitMapToRestaurants(restaurants)
    } catch (error) {
      if (requestId !== searchRequestIdRef.current) return

      setSearchErrorMessage(
        error instanceof Error ? error.message : '검색 결과를 불러오지 못했습니다',
      )
      setSearchState('error')
      displayRestaurantsOnMap([])
    }
  }

  function selectSearchResult(restaurant: Restaurant) {
    focusRestaurantOnMap(restaurant)
  }

  function selectBookmarkedRestaurant(restaurant: Restaurant) {
    bookmarkFocusModeRef.current = true
    displayRestaurantsOnMap([restaurant], { preserveViewport: true })
    focusRestaurantOnMap(restaurant)
  }

  function focusRestaurantOnMap(restaurant: Restaurant) {
    const kakaoMaps = kakaoMapsRef.current
    const map = kakaoMapRef.current

    if (!kakaoMaps || !map) {
      showToast('지도가 아직 준비되지 않았습니다')
      return
    }

    map.setCenter(new kakaoMaps.LatLng(restaurant.latitude, restaurant.longitude))
    map.setLevel(FOCUSED_LEVEL)
    setSelectedRestaurant(restaurant)
    setActiveSidePanel('restaurant')
  }

  async function focusCurrentLocationOnMap() {
    const kakaoMaps = kakaoMapsRef.current
    const map = kakaoMapRef.current

    if (!kakaoMaps || !map) {
      showToast('지도가 아직 준비되지 않았습니다')
      return
    }

    try {
      const position = await getCurrentPosition()
      const nextPosition = {
        latitude: position.coords.latitude,
        longitude: position.coords.longitude,
      }
      const latLng = new kakaoMaps.LatLng(
        nextPosition.latitude,
        nextPosition.longitude,
      )

      setCurrentPosition(nextPosition)
      map.setCenter(latLng)
      map.setLevel(FOCUSED_LEVEL)

      if (currentLocationOverlayRef.current) {
        currentLocationOverlayRef.current.setPosition(latLng)
      } else {
        const overlay = new kakaoMaps.CustomOverlay({
          content: createCurrentLocationMarker(),
          position: latLng,
          xAnchor: 0.5,
          yAnchor: 0.5,
        })
        overlay.setMap(map)
        currentLocationOverlayRef.current = overlay
      }

      showToast('현재 위치로 이동했습니다')
    } catch {
      showToast('현재 위치를 가져오지 못했습니다')
    }
  }

  function handleCall(restaurant: Restaurant) {
    if (!restaurant.phone.trim()) {
      showToast('등록된 전화번호가 없습니다')
      return
    }

    copyToClipboard(restaurant.phone, '전화번호가 복사되었습니다')
  }

  function handleRoute(restaurant: Restaurant) {
    if (!restaurant.link.trim()) {
      showToast('길찾기 링크가 없습니다')
      return
    }

    window.open(restaurant.link, '_blank', 'noopener,noreferrer')
  }

  function handleShare(restaurant: Restaurant) {
    if (!restaurant.link.trim()) {
      showToast('공유 가능한 링크가 없습니다')
      return
    }

    copyToClipboard(restaurant.link, '링크가 복사되었습니다')
  }

  async function loadRestaurantDetail(restaurant: Restaurant, forceFresh = false) {
    const requestId = ++detailRequestIdRef.current
    const controller = new AbortController()
    const query = restaurant.name
    const accessToken = authSession?.access_token

    setDetailErrorMessage('')
    setDetailData(null)
    setReviewSort('real')
    setReviewPage(0)
    setDetailHasMoreReviews(false)
    setIsReviewBatchLoading(false)
    setDetailState(forceFresh ? 'analyzing' : 'loading')

    try {
      let detailJson: Awaited<ReturnType<typeof fetchDetailJson>>

      if (!forceFresh) {
        const cached = await fetchDetailJson(
          buildReviewSearchPath('/api/search/cached', query, {
            restaurant,
          }),
          controller.signal,
          accessToken,
        )
        if (requestId !== detailRequestIdRef.current) return

        if ((cached.reviews ?? []).length >= REVIEW_BATCH_SIZE) {
          detailJson = cached
        } else {
          setDetailState('analyzing')
          try {
            detailJson = await fetchDetailJson(
              buildReviewSearchPath('/api/search', query, {
                naverStart: 1,
                restaurant,
              }),
              controller.signal,
              accessToken,
            )
          } catch (error) {
            if (isAnalysisUsageRequiredError(error)) throw error
            if ((cached.reviews ?? []).length === 0) throw error
            detailJson = cached
            showToast('추가 리뷰를 불러오지 못해 저장된 리뷰만 표시합니다')
          }
        }
      } else {
        detailJson = await fetchDetailJson(
          buildReviewSearchPath('/api/search', query, {
            naverStart: 1,
            refresh: true,
            restaurant,
          }),
          controller.signal,
          accessToken,
        )
      }

      if (requestId !== detailRequestIdRef.current) return

      applyUsageProfile(detailJson.usage)

      const reviews = (detailJson.reviews ?? []).map(parseBlogReview)
      if (reviews.length === 0) {
        setDetailState('noData')
        return
      }

      setDetailData({
        reviews,
        keywords: buildKeywords(reviews),
      })
      setDetailHasMoreReviews(
        Boolean(detailJson.hasMore) && reviews.length < MAX_REVIEW_RESULTS,
      )
      setDetailState('loaded')
    } catch (error) {
      if (requestId !== detailRequestIdRef.current) return
      const message =
        error instanceof Error
          ? error.message
          : '상세 데이터를 불러오지 못했습니다'
      setDetailErrorMessage(message)
      if (isAnalysisUsageRequiredError(error)) {
        showToast(message || ANALYSIS_USAGE_REQUIRED_MESSAGE)
      }
      setDetailState('error')
    }
  }

  function openDetailPanel(restaurant: Restaurant, forceFresh = false) {
    setSelectedRestaurant(restaurant)
    setActiveSidePanel('detail')
    loadRestaurantDetail(restaurant, forceFresh)
  }

  function handleDetailButtonClick(restaurant: Restaurant) {
    const usageInfo = getDetailUsageInfo(restaurant, userProfileState.profile)
    if (!usageInfo.canAnalyze) {
      showToast('분석을 위해 코인을 충전해주세요')
      setSelectedRestaurant(null)
      setActiveSidePanel('settings')
      if (authSession && !userProfileState.hasLoaded && !userProfileState.isLoading) {
        void loadUserProfile()
      }
      return
    }

    openDetailPanel(restaurant)
  }

  async function loadReviewBatchForPage(pageIndex: number) {
    if (
      !selectedRestaurant ||
      !detailData ||
      !detailHasMoreReviews ||
      isReviewBatchLoading
    ) {
      return
    }

    const pageStart = pageIndex * REVIEW_PAGE_SIZE
    if (
      pageStart < detailData.reviews.length ||
      detailData.reviews.length >= MAX_REVIEW_RESULTS
    ) {
      return
    }

    const requestId = ++reviewBatchRequestIdRef.current
    const controller = new AbortController()
    const naverStart =
      Math.floor(pageStart / REVIEW_BATCH_SIZE) * REVIEW_BATCH_SIZE + 1

    setIsReviewBatchLoading(true)

    try {
      const detailJson = await fetchDetailJson(
        buildReviewSearchPath('/api/search', selectedRestaurant.name, {
          naverStart,
          restaurant: selectedRestaurant,
        }),
        controller.signal,
        authSession?.access_token,
      )
      if (requestId !== reviewBatchRequestIdRef.current) return

      applyUsageProfile(detailJson.usage)

      const nextReviews = (detailJson.reviews ?? []).map(parseBlogReview)
      const reviews = mergeReviews(detailData.reviews, nextReviews)

      setDetailData({
        reviews,
        keywords: buildKeywords(reviews),
      })
      setDetailHasMoreReviews(
        Boolean(detailJson.hasMore) && reviews.length < MAX_REVIEW_RESULTS,
      )
    } catch (error) {
      if (requestId !== reviewBatchRequestIdRef.current) return
      const lastLoadedPage = Math.max(
        0,
        Math.ceil(detailData.reviews.length / REVIEW_PAGE_SIZE) - 1,
      )
      setReviewPage((current) => Math.min(current, lastLoadedPage))
      setDetailHasMoreReviews(false)
      showToast(
        isAnalysisUsageRequiredError(error) && error instanceof Error
          ? error.message
          : '추가 리뷰를 불러오지 못했습니다',
      )
    } finally {
      if (requestId === reviewBatchRequestIdRef.current) {
        setIsReviewBatchLoading(false)
      }
    }
  }

  async function loadAiRecommendations(page: number, regionScope = aiRegionScope) {
    setAiRecommendState((previous) => ({
      ...previous,
      page,
      isLoading: true,
      errorMessage: '',
    }))

    try {
      const params = new URLSearchParams({
        threshold: '0.1',
        page: page.toString(),
        pageSize: '10',
        regionScope,
      })
      if (currentPosition) {
        params.set('lat', currentPosition.latitude.toString())
        params.set('lng', currentPosition.longitude.toString())
      }

      const response = await fetch(
        `${BACKEND_BASE_URL}/api/ai-recommendations?${params.toString()}`,
      )

      if (!response.ok) {
        throw new Error(`서버 응답 ${response.status}`)
      }

      const data = (await response.json()) as {
        items?: Record<string, unknown>[]
        page?: number | string
        hasNext?: boolean
        regionLabel?: string
        currentRegion?: {
          si?: string
          gu?: string
          dong?: string
          label?: string
        } | null
        isRegionFiltered?: boolean
      }
      const items = (data.items ?? [])
        .map(parseAiRecommendItem)
        .filter((item) => item.id !== 0)

      setAiRecommendState({
        items,
        page: Number(data.page ?? page) || page,
        hasNext: data.hasNext === true,
        isLoading: false,
        errorMessage: '',
        hasLoaded: true,
        regionLabel: cleanText(data.regionLabel),
        currentRegionLabel: cleanText(data.currentRegion?.label),
        currentRegionSi: cleanText(data.currentRegion?.si),
        currentRegionGu: cleanText(data.currentRegion?.gu),
        currentRegionDong: cleanText(data.currentRegion?.dong),
        isRegionFiltered: data.isRegionFiltered === true,
      })
    } catch (error) {
      setAiRecommendState((previous) => ({
        ...previous,
        isLoading: false,
        errorMessage:
          error instanceof Error ? error.message : 'AI 추천 API 오류',
        hasLoaded: true,
      }))
    }
  }

  function openAiPanel() {
    setSelectedRestaurant(null)
    setActiveSidePanel((current) => {
      const next = current === 'ai' ? 'search' : 'ai'
      if (next === 'ai' && !aiRecommendState.hasLoaded) {
        loadAiRecommendations(1)
      }
      return next
    })
  }

  async function loadRecentAnalyses() {
    const token = authSession?.access_token
    if (!token || isTemporaryAdmin) {
      setRecentAnalysesState({
        data: { today: '', freeItems: [], expiredItems: [] },
        isLoading: false,
        errorMessage: '',
        hasLoaded: true,
      })
      return
    }

    setRecentAnalysesState((previous) => ({
      ...previous,
      isLoading: true,
      errorMessage: '',
    }))

    try {
      const data = await fetchRecentAnalyses(token)
      setRecentAnalysesState({
        data,
        isLoading: false,
        errorMessage: '',
        hasLoaded: true,
      })
    } catch (error) {
      setRecentAnalysesState((previous) => ({
        ...previous,
        isLoading: false,
        errorMessage:
          error instanceof Error
            ? error.message
            : '최근분석 목록을 불러오지 못했습니다',
        hasLoaded: true,
      }))
    }
  }

  function openRecentPanel() {
    const shouldOpen = activeSidePanel !== 'recent'
    setSelectedRestaurant(null)
    setActiveSidePanel(shouldOpen ? 'recent' : 'search')

    if (
      shouldOpen &&
      !recentAnalysesState.hasLoaded &&
      !recentAnalysesState.isLoading
    ) {
      void loadRecentAnalyses()
    }
  }

  function focusRecentAnalysis(item: RecentAnalysisItem) {
    const restaurant = recentAnalysisToRestaurant(item)
    if (!restaurant) {
      showToast('최근분석 위치 정보를 찾지 못했습니다')
      return
    }

    focusRestaurantOnMap(restaurant)
  }

  function openSettingsPanel() {
    const shouldOpen = activeSidePanel !== 'settings'
    setSelectedRestaurant(null)
    setActiveSidePanel(shouldOpen ? 'settings' : 'search')

    if (
      shouldOpen &&
      authSession &&
      !userProfileState.hasLoaded &&
      !userProfileState.isLoading
    ) {
      void loadUserProfile()
    }
  }

  function changeAiRegionScope(regionScope: AiRegionScope) {
    setAiRegionScope(regionScope)
    if (activeSidePanel === 'ai') {
      loadAiRecommendations(1, regionScope)
    }
  }

  function focusAiRecommendation(item: AiRecommendItem) {
    const restaurant = aiRecommendToRestaurant(item)
    if (!restaurant) {
      showToast('위치 정보가 없는 추천입니다')
      return
    }

    focusRestaurantOnMap(restaurant)
  }

  useEffect(() => {
    let canceled = false

    async function initializeMap() {
      let viewportSearchTimer = 0
      let viewportSearchRequestId = 0
      let lastSearchedCenter: MapPoint | null = null
      let lastSearchedLevel: number | null = null

      function shouldRefreshViewport(center: MapPoint, level: number) {
        if (!lastSearchedCenter || lastSearchedLevel === null) return true

        return (
          distanceMeters(center, lastSearchedCenter) >= REFRESH_DISTANCE_METERS ||
          level !== lastSearchedLevel
        )
      }

      function scheduleViewportSearch(map: KakaoMap) {
        if (searchModeRef.current || bookmarkFocusModeRef.current) return

        const center = pointFromLatLng(map.getCenter())
        const level = map.getLevel()
        if (!shouldRefreshViewport(center, level)) return

        const radius = calculateViewportRadius(map)
        if (radius <= 0) return

        window.clearTimeout(viewportSearchTimer)
        viewportSearchTimer = window.setTimeout(async () => {
          const requestId = ++viewportSearchRequestId

          try {
            const restaurants = await fetchNearbyRestaurants(center, radius)
            if (canceled || requestId !== viewportSearchRequestId) return

            viewportRestaurantsRef.current = restaurants
            if (!searchModeRef.current) {
              displayRestaurantsOnMap(restaurants)
            }
            lastSearchedCenter = center
            lastSearchedLevel = level
            setPlacesErrorMessage('')
          } catch (error) {
            if (canceled || requestId !== viewportSearchRequestId) return

            setPlacesErrorMessage(
              error instanceof Error
                ? error.message
                : '주변 장소를 불러오지 못했습니다',
            )
          }
        }, VIEWPORT_DEBOUNCE_MS)
      }

      try {
        const kakaoJsKey = await fetchKakaoJsKey()
        const kakaoMaps = await loadKakaoMaps(kakaoJsKey)

        if (canceled || !mapContainerRef.current) return

        const center = new kakaoMaps.LatLng(
          INITIAL_CENTER.latitude,
          INITIAL_CENTER.longitude,
        )
        const map = new kakaoMaps.Map(mapContainerRef.current, {
          center,
          level: INITIAL_LEVEL,
        })
        kakaoMapsRef.current = kakaoMaps
        kakaoMapRef.current = map

        setLoadState('ready')
        kakaoMaps.event.addListener(map, 'idle', () => scheduleViewportSearch(map))
        kakaoMaps.event.addListener(map, 'click', () => {
          const wasBookmarkFocusMode = bookmarkFocusModeRef.current
          bookmarkFocusModeRef.current = false
          setSelectedRestaurant(null)
          setActiveSidePanel('search')
          if (wasBookmarkFocusMode) {
            displayRestaurantsOnMap(viewportRestaurantsRef.current)
            scheduleViewportSearch(map)
          }
        })

        for (const delay of [100, 300, 700]) {
          window.setTimeout(() => {
            if (!canceled) map.relayout()
          }, delay)
        }

        try {
          const position = await getCurrentPosition()
          if (canceled) return
          setCurrentPosition({
            latitude: position.coords.latitude,
            longitude: position.coords.longitude,
          })

          const currentCenter = new kakaoMaps.LatLng(
            position.coords.latitude,
            position.coords.longitude,
          )
          const currentLocationOverlay = new kakaoMaps.CustomOverlay({
            content: createCurrentLocationMarker(),
            position: currentCenter,
            xAnchor: 0.5,
            yAnchor: 0.5,
          })

          map.setCenter(currentCenter)
          currentLocationOverlay.setMap(map)
          currentLocationOverlayRef.current = currentLocationOverlay
        } catch {
          // 위치 권한 거부나 브라우저 제한이 있어도 기본 위치의 지도를 유지합니다.
        }

        scheduleViewportSearch(map)
      } catch (error) {
        if (canceled) return

        setErrorMessage(
          error instanceof Error
            ? error.message
            : '카카오맵을 불러오지 못했습니다',
        )
        setLoadState('error')
      }
    }

    initializeMap()

    return () => {
      canceled = true
      clearRestaurantOverlays()
    }
  }, [])

  const sortedDetailReviews = detailData
    ? [...detailData.reviews].sort((a, b) => {
        if (reviewSort === 'latest') {
          return b.date.localeCompare(a.date) || b.id - a.id
        }
        return a.adProbability - b.adProbability || b.id - a.id
      })
    : []
  const loadedReviewPages =
    sortedDetailReviews.length === 0
      ? 0
      : Math.ceil(sortedDetailReviews.length / REVIEW_PAGE_SIZE)
  const reviewTotalPages = detailHasMoreReviews
    ? Math.ceil(MAX_REVIEW_RESULTS / REVIEW_PAGE_SIZE)
    : loadedReviewPages
  const reviewPageStart = reviewPage * REVIEW_PAGE_SIZE
  const isReviewPageLoaded = reviewPageStart < sortedDetailReviews.length
  const showReviewPageSkeleton =
    isReviewBatchLoading && !isReviewPageLoaded && reviewTotalPages > 0
  const visibleDetailReviews = showReviewPageSkeleton
    ? []
    : sortedDetailReviews.slice(
        reviewPageStart,
        reviewPageStart + REVIEW_PAGE_SIZE,
      )

  function changeReviewPage(nextPage: number) {
    const normalizedPage = Math.max(0, Math.min(nextPage, reviewTotalPages - 1))
    setReviewPage(normalizedPage)

    if (
      normalizedPage * REVIEW_PAGE_SIZE >= sortedDetailReviews.length &&
      detailHasMoreReviews
    ) {
      loadReviewBatchForPage(normalizedPage)
    }
  }

  function changeReviewSort(nextSort: 'real' | 'latest') {
    setReviewSort(nextSort)
    setReviewPage(0)
  }

  const recentFreeItems = recentAnalysesState.data?.freeItems ?? []
  const recentExpiredItems = recentAnalysesState.data?.expiredItems ?? []
  const hasRecentAnalysisItems =
    recentFreeItems.length > 0 || recentExpiredItems.length > 0

  return (
    <main className="map-page">
      <section className="side-panel-column" aria-label="지도 사이드 패널">
      {!isLoggedIn ? (
        <aside className="restaurant-panel login-panel" aria-label="로그인">
          <section className="login-panel-body">
            <div className="login-panel-header">
              <div className="login-mark" aria-hidden="true">
                <img src={appLogoUrl} alt="" />
              </div>
              <div>
                <p>Sign in</p>
                <h2>로그인이 필요합니다</h2>
              </div>
            </div>

            <button
              type="button"
              className="login-oauth-button"
              disabled={!supabase || authStatus === 'checking'}
              onClick={signInWithGoogle}
            >
              <span aria-hidden="true">G</span>
              Google로 계속하기
            </button>

            {authErrorMessage && (
              <p className="login-error-message">{authErrorMessage}</p>
            )}

            <div className="login-divider" aria-hidden="true" />

            <button
              type="button"
              className="login-temp-button"
              onClick={signInAsTemporaryAdmin}
            >
              관리자용 임시 로그인
            </button>
          </section>
        </aside>
      ) : (
        <>
      {activeSidePanel === 'search' && (
        <aside className="restaurant-panel search-panel" aria-label="장소 검색">
          <section className="search-panel-body">
            <div className="search-panel-header">
              <Search aria-hidden="true" size={22} strokeWidth={2.2} />
              <div>
                <p>Search</p>
                <h2>장소 검색</h2>
              </div>
            </div>

            <form className="map-search-form" onSubmit={submitRestaurantSearch}>
              <label className="map-search-field">
                <Search aria-hidden="true" size={18} strokeWidth={2.2} />
                <input
                  type="search"
                  value={searchInput}
                  placeholder="음식점 또는 메뉴를 검색"
                  onChange={(event) => {
                    const nextValue = event.target.value
                    setSearchInput(nextValue)
                    if (!nextValue.trim() && searchModeRef.current) {
                      clearRestaurantSearch()
                    }
                  }}
                />
              </label>
              <button
                type="submit"
                className="map-search-submit"
                aria-label="검색"
                disabled={searchState === 'loading'}
              >
                {searchState === 'loading' ? (
                  <LoaderCircle
                    aria-hidden="true"
                    className="spinning-icon"
                    size={18}
                    strokeWidth={2.2}
                  />
                ) : (
                  <Search aria-hidden="true" size={18} strokeWidth={2.2} />
                )}
              </button>
            </form>

            {searchState === 'idle' && (
              <div className="search-empty-state">
                <Search aria-hidden="true" size={26} strokeWidth={2.1} />
                <strong>검색어를 입력하세요</strong>
              </div>
            )}

            {searchState === 'loading' && (
              <div className="detail-state-card search-state-card">
                <LoaderCircle
                  aria-hidden="true"
                  className="spinning-icon"
                  size={24}
                  strokeWidth={2.2}
                />
                <strong>검색 결과를 불러오는 중입니다</strong>
              </div>
            )}

            {searchState === 'error' && (
              <div className="detail-state-card detail-state-error search-state-card">
                <AlertCircle aria-hidden="true" size={24} strokeWidth={2.2} />
                <strong>검색 결과를 불러오지 못했어요</strong>
                <p>{searchErrorMessage}</p>
                <button
                  type="button"
                  className="detail-secondary-button"
                  onClick={() => submitRestaurantSearch()}
                >
                  <RefreshCw aria-hidden="true" size={16} strokeWidth={2.2} />
                  다시 시도
                </button>
              </div>
            )}

            {searchState === 'loaded' && searchResults.length === 0 && (
              <div className="bookmark-empty">
                "{searchQuery}" 검색 결과가 없습니다
              </div>
            )}

            {searchState === 'loaded' && searchResults.length > 0 && (
              <div className="search-results">
                <div className="search-results-summary">
                  <strong>"{searchQuery}"</strong>
                  <span>{searchResults.length}개 결과</span>
                </div>
                <ul className="search-result-list">
                  {searchResults.map((restaurant) => (
                    <li key={restaurant.id}>
                      <button
                        type="button"
                        className="search-result-card"
                        onClick={() => selectSearchResult(restaurant)}
                      >
                        <RestaurantThumb
                          restaurant={restaurant}
                          className="bookmark-thumb search-result-thumb"
                        />
                        <span className="search-result-copy">
                          <strong>{restaurant.name}</strong>
                          <small>{restaurant.category}</small>
                          <span>
                            {restaurant.address || '주소 정보 없음'} ·{' '}
                            {formatDistance(restaurant.distance)}
                          </span>
                        </span>
                      </button>
                    </li>
                  ))}
                </ul>
              </div>
            )}
          </section>
        </aside>
      )}
      {selectedRestaurant && activeSidePanel === 'restaurant' && (
        <aside className="restaurant-panel" aria-label="선택한 가게 정보">
          <button
            type="button"
            className="panel-close-button"
            aria-label="가게 정보 닫기"
            onClick={() => {
              setSelectedRestaurant(null)
              setActiveSidePanel('search')
            }}
          >
            <X aria-hidden="true" size={19} strokeWidth={2.2} />
          </button>

          <div className="restaurant-panel-hero">
            <RestaurantThumb
              restaurant={selectedRestaurant}
              className="restaurant-thumbnail"
            />
          </div>

          <section className="restaurant-panel-body">
            <p className="restaurant-category">{selectedRestaurant.category}</p>
            <h2>{selectedRestaurant.name}</h2>
            <p className="restaurant-meta">
              <MapPin aria-hidden="true" size={15} strokeWidth={2.1} />
              <span>
                {selectedRestaurant.address || '주소 정보 없음'} ·{' '}
                {formatDistance(selectedRestaurant.distance)}
              </span>
            </p>

            <div className="restaurant-actions" aria-label="가게 액션">
              <button type="button" onClick={() => handleCall(selectedRestaurant)}>
                <Phone aria-hidden="true" size={20} strokeWidth={2.1} />
                <span>Call</span>
              </button>
              <button
                type="button"
                onClick={() => toggleBookmark(selectedRestaurant)}
              >
                {bookmarkedIds.includes(getRestaurantStoreId(selectedRestaurant)) ? (
                  <BookmarkCheck aria-hidden="true" size={20} strokeWidth={2.1} />
                ) : (
                  <Bookmark aria-hidden="true" size={20} strokeWidth={2.1} />
                )}
                <span>Save</span>
              </button>
              <button type="button" onClick={() => handleRoute(selectedRestaurant)}>
                <Navigation aria-hidden="true" size={20} strokeWidth={2.1} />
                <span>Route</span>
              </button>
              <button type="button" onClick={() => handleShare(selectedRestaurant)}>
                <Share2 aria-hidden="true" size={20} strokeWidth={2.1} />
                <span>Share</span>
              </button>
            </div>

            <button
              type="button"
              className="detail-button"
              onClick={() => handleDetailButtonClick(selectedRestaurant)}
            >
              <Info aria-hidden="true" size={18} strokeWidth={2.2} />
              {getDetailUsageInfo(selectedRestaurant, userProfileState.profile).label}
            </button>
          </section>
        </aside>
      )}
      {selectedRestaurant && activeSidePanel === 'detail' && (
        <aside className="restaurant-panel detail-panel" aria-label="가게 상세 정보">
          <div className="detail-panel-topbar">
            <button
              type="button"
              className="panel-icon-button"
              aria-label="가게 정보로 돌아가기"
              onClick={() => setActiveSidePanel('restaurant')}
            >
              <ArrowLeft aria-hidden="true" size={19} strokeWidth={2.2} />
            </button>
            <strong>{selectedRestaurant.name}</strong>
            <button
              type="button"
              className="panel-icon-button"
              aria-label="상세 정보 닫기"
              onClick={() => {
                setSelectedRestaurant(null)
                setActiveSidePanel('search')
              }}
            >
              <X aria-hidden="true" size={19} strokeWidth={2.2} />
            </button>
          </div>

          <section className="detail-panel-body">
            <div className="detail-restaurant-card">
              <RestaurantThumb
                restaurant={selectedRestaurant}
                className="bookmark-thumb detail-thumb"
              />
              <div>
                <p>{selectedRestaurant.category}</p>
                <h2>{selectedRestaurant.name}</h2>
                <small>
                  {selectedRestaurant.address || '주소 정보 없음'} ·{' '}
                  {formatDistance(selectedRestaurant.distance)}
                </small>
              </div>
            </div>

            <div className="restaurant-actions detail-actions" aria-label="가게 액션">
              <button type="button" onClick={() => handleCall(selectedRestaurant)}>
                <Phone aria-hidden="true" size={20} strokeWidth={2.1} />
                <span>Call</span>
              </button>
              <button
                type="button"
                onClick={() => toggleBookmark(selectedRestaurant)}
              >
                {bookmarkedIds.includes(getRestaurantStoreId(selectedRestaurant)) ? (
                  <BookmarkCheck aria-hidden="true" size={20} strokeWidth={2.1} />
                ) : (
                  <Bookmark aria-hidden="true" size={20} strokeWidth={2.1} />
                )}
                <span>Save</span>
              </button>
              <button type="button" onClick={() => handleRoute(selectedRestaurant)}>
                <Navigation aria-hidden="true" size={20} strokeWidth={2.1} />
                <span>Route</span>
              </button>
              <button type="button" onClick={() => handleShare(selectedRestaurant)}>
                <Share2 aria-hidden="true" size={20} strokeWidth={2.1} />
                <span>Share</span>
              </button>
            </div>

            {(detailState === 'loading' || detailState === 'analyzing') && (
              <div className="detail-state-card">
                <LoaderCircle
                  aria-hidden="true"
                  className="spinning-icon"
                  size={24}
                  strokeWidth={2.2}
                />
                <strong>
                  {detailState === 'loading'
                    ? '저장된 리뷰를 확인하는 중입니다'
                    : '새 리뷰를 수집하고 분석하는 중입니다'}
                </strong>
                <p>조금만 기다려 주세요. 지도는 그대로 사용할 수 있습니다.</p>
              </div>
            )}

            {detailState === 'noData' && (
              <div className="detail-state-card">
                <AlertCircle aria-hidden="true" size={24} strokeWidth={2.2} />
                <strong>아직 분석된 리뷰가 없습니다</strong>
                <p>새 분석을 다시 요청해 볼 수 있습니다.</p>
                <button
                  type="button"
                  className="detail-secondary-button"
                  onClick={() => openDetailPanel(selectedRestaurant, true)}
                >
                  <RefreshCw aria-hidden="true" size={16} strokeWidth={2.2} />
                  다시 분석
                </button>
              </div>
            )}

            {detailState === 'error' && (
              <div className="detail-state-card detail-state-error">
                <AlertCircle aria-hidden="true" size={24} strokeWidth={2.2} />
                <strong>상세 정보를 불러오지 못했습니다</strong>
                <p>{detailErrorMessage}</p>
                <button
                  type="button"
                  className="detail-secondary-button"
                  onClick={() => openDetailPanel(selectedRestaurant, true)}
                >
                  <RefreshCw aria-hidden="true" size={16} strokeWidth={2.2} />
                  다시 시도
                </button>
              </div>
            )}

            {detailState === 'loaded' && detailData && (
              <>
                <section className="detail-section">
                  <div className="detail-section-heading">
                    <Info aria-hidden="true" size={17} strokeWidth={2.2} />
                    <h3>리뷰 키워드</h3>
                  </div>
                  {detailData.keywords.length > 0 ? (
                    <div className="keyword-cloud">
                      {detailData.keywords.map((keyword) => (
                        <span
                          key={keyword.word}
                          style={{
                            fontSize: `${Math.min(18, 12 + keyword.count * 2)}px`,
                          }}
                        >
                          {keyword.word}
                        </span>
                      ))}
                    </div>
                  ) : (
                    <p className="detail-muted">표시할 키워드가 없습니다.</p>
                  )}
                </section>

                <section className="detail-section review-section">
                  <div className="detail-section-heading">
                    <Clock aria-hidden="true" size={17} strokeWidth={2.2} />
                    <h3>블로그 리뷰</h3>
                  </div>
                  <div className="review-tabs" role="tablist" aria-label="리뷰 정렬">
                    <button
                      type="button"
                      className={reviewSort === 'real' ? 'active' : ''}
                      onClick={() => changeReviewSort('real')}
                    >
                      진성순
                    </button>
                    <button
                      type="button"
                      className={reviewSort === 'latest' ? 'active' : ''}
                      onClick={() => changeReviewSort('latest')}
                    >
                      최신순
                    </button>
                  </div>
                  <ul className="review-list">
                    {showReviewPageSkeleton
                      ? Array.from({ length: REVIEW_PAGE_SIZE }, (_, index) => (
                          <li key={`review-skeleton-${index}`}>
                            <article
                              className="review-card review-card-skeleton"
                              aria-hidden="true"
                            >
                              <span className="skeleton-pill" />
                              <span className="skeleton-line skeleton-title" />
                              <span className="skeleton-line" />
                              <span className="skeleton-line skeleton-short" />
                              <span className="skeleton-line skeleton-meta" />
                            </article>
                          </li>
                        ))
                      : visibleDetailReviews.map((review) => (
                          <li key={`${review.id}-${review.url || review.title}`}>
                            {review.url ? (
                              <a
                                className="review-card"
                                href={review.url}
                                target="_blank"
                                rel="noopener noreferrer"
                                aria-label={`${review.title} 원문 열기`}
                              >
                                <span className={`review-grade ${review.grade}`}>
                                  {gradeLabel(review.grade)}
                                </span>
                                <strong>{review.title}</strong>
                                <p>{review.preview}</p>
                                <small>
                                  {review.author}
                                  {review.date ? ` · ${review.date}` : ''}
                                </small>
                              </a>
                            ) : (
                              <article className="review-card">
                                <span className={`review-grade ${review.grade}`}>
                                  {gradeLabel(review.grade)}
                                </span>
                                <strong>{review.title}</strong>
                                <p>{review.preview}</p>
                                <small>
                                  {review.author}
                                  {review.date ? ` · ${review.date}` : ''}
                                </small>
                              </article>
                            )}
                          </li>
                        ))}
                  </ul>
                  {reviewTotalPages > 1 && (
                    <div className="review-pagination">
                      <button
                        type="button"
                        disabled={reviewPage <= 0 || isReviewBatchLoading}
                        onClick={() => changeReviewPage(reviewPage - 1)}
                      >
                        이전
                      </button>
                      <span>
                        {reviewPage + 1} / {reviewTotalPages}
                      </span>
                      <button
                        type="button"
                        disabled={
                          reviewPage >= reviewTotalPages - 1 ||
                          isReviewBatchLoading
                        }
                        onClick={() => changeReviewPage(reviewPage + 1)}
                      >
                        다음
                      </button>
                    </div>
                  )}
                </section>
              </>
            )}
          </section>
        </aside>
      )}
      {activeSidePanel === 'bookmarks' && (
        <aside className="restaurant-panel bookmark-panel" aria-label="북마크">
          <button
            type="button"
            className="panel-close-button"
            aria-label="북마크 닫기"
            onClick={() => setActiveSidePanel('search')}
          >
            <X aria-hidden="true" size={19} strokeWidth={2.2} />
          </button>

          <section className="bookmark-panel-body">
            <div className="bookmark-panel-header">
              <BookmarkCheck aria-hidden="true" size={22} strokeWidth={2.2} />
              <div>
                <p>Saved Places</p>
                <h2>북마크</h2>
              </div>
            </div>

            {bookmarkedRestaurants.length === 0 ? (
              <div className="bookmark-empty">아직 북마크한 가게가 없습니다</div>
            ) : (
              <ul className="bookmark-list">
                {bookmarkedRestaurants.map((restaurant) => (
                  <li key={getRestaurantStoreId(restaurant)}>
                    <button
                      type="button"
                      className="bookmark-list-item"
                      onClick={() => selectBookmarkedRestaurant(restaurant)}
                    >
                      <RestaurantThumb
                        restaurant={restaurant}
                        className="bookmark-thumb"
                      />
                      <span className="bookmark-copy">
                        <strong>{restaurant.name}</strong>
                        <small>
                          {restaurant.category} ·{' '}
                          {restaurant.address || '주소 정보 없음'}
                        </small>
                      </span>
                    </button>
                    <button
                      type="button"
                      className="bookmark-remove-button"
                      aria-label={`${restaurant.name} 북마크 해제`}
                      onClick={(event) => {
                        event.stopPropagation()
                        toggleBookmark(restaurant)
                      }}
                    >
                      <BookmarkCheck
                        aria-hidden="true"
                        size={18}
                        strokeWidth={2.2}
                      />
                    </button>
                  </li>
                ))}
              </ul>
            )}
          </section>
        </aside>
      )}
      {activeSidePanel === 'recent' && (
        <aside className="restaurant-panel bookmark-panel recent-panel" aria-label="최근분석">
          <button
            type="button"
            className="panel-close-button"
            aria-label="최근분석 닫기"
            onClick={() => setActiveSidePanel('search')}
          >
            <X aria-hidden="true" size={19} strokeWidth={2.2} />
          </button>

          <section className="bookmark-panel-body">
            <div className="bookmark-panel-header recent-panel-header">
              <Clock aria-hidden="true" size={22} strokeWidth={2.2} />
              <div>
                <p>Recent Analysis</p>
                <h2>최근분석</h2>
              </div>
            </div>

            {isTemporaryAdmin || !authSession ? (
              <div className="bookmark-empty">
                Google 로그인 후 최근분석을 확인할 수 있습니다
              </div>
            ) : (
              <>
                {recentAnalysesState.isLoading && !recentAnalysesState.data && (
                  <div className="detail-state-card">
                    <LoaderCircle
                      aria-hidden="true"
                      className="spinning-icon"
                      size={24}
                      strokeWidth={2.2}
                    />
                    <strong>최근분석을 불러오는 중입니다</strong>
                    <p>무료 분석 기간인 가게를 확인하고 있어요.</p>
                  </div>
                )}

                {recentAnalysesState.errorMessage && (
                  <div className="detail-state-card detail-state-error">
                    <AlertCircle aria-hidden="true" size={24} strokeWidth={2.2} />
                    <strong>최근분석을 불러오지 못했어요</strong>
                    <p>{recentAnalysesState.errorMessage}</p>
                    <button
                      type="button"
                      className="detail-secondary-button"
                      onClick={loadRecentAnalyses}
                    >
                      <RefreshCw aria-hidden="true" size={16} strokeWidth={2.2} />
                      다시 시도
                    </button>
                  </div>
                )}

                {!recentAnalysesState.isLoading &&
                  !recentAnalysesState.errorMessage &&
                  recentAnalysesState.hasLoaded &&
                  !hasRecentAnalysisItems && (
                    <div className="bookmark-empty">
                      아직 분석한 가게가 없습니다
                    </div>
                  )}

                {hasRecentAnalysisItems && (
                  <div className="recent-analysis-groups">
                    <section className="recent-analysis-section">
                      <div className="recent-section-heading">
                        <strong>무료 분석 가능</strong>
                        <span>{recentFreeItems.length}개</span>
                      </div>
                      {recentFreeItems.length === 0 ? (
                        <div className="recent-section-empty">
                          무료 기간인 가게가 없습니다
                        </div>
                      ) : (
                        <ul className="bookmark-list recent-analysis-list">
                          {recentFreeItems.map((item) => (
                            <li key={`free-${item.storeId}`}>
                              <button
                                type="button"
                                className="bookmark-list-item recent-analysis-item"
                                onClick={() => focusRecentAnalysis(item)}
                              >
                                <RestaurantThumb
                                  restaurant={item.restaurant}
                                  className="bookmark-thumb"
                                />
                                <span className="bookmark-copy">
                                  <strong>{item.restaurant.name}</strong>
                                  <small>
                                    {item.restaurant.category} ·{' '}
                                    {item.restaurant.address || '주소 정보 없음'}
                                  </small>
                                  <em>
                                    {item.analyzedDate} · 무료-
                                    {item.remainingFreeDays}일 남음
                                  </em>
                                </span>
                              </button>
                            </li>
                          ))}
                        </ul>
                      )}
                    </section>

                    <section className="recent-analysis-section">
                      <div className="recent-section-heading">
                        <strong>지난 검색</strong>
                        <span>{recentExpiredItems.length}개</span>
                      </div>
                      {recentExpiredItems.length === 0 ? (
                        <div className="recent-section-empty">
                          지난 검색 가게가 없습니다
                        </div>
                      ) : (
                        <ul className="bookmark-list recent-analysis-list">
                          {recentExpiredItems.map((item) => (
                            <li key={`expired-${item.storeId}`}>
                              <button
                                type="button"
                                className="bookmark-list-item recent-analysis-item"
                                onClick={() => focusRecentAnalysis(item)}
                              >
                                <RestaurantThumb
                                  restaurant={item.restaurant}
                                  className="bookmark-thumb"
                                />
                                <span className="bookmark-copy">
                                  <strong>{item.restaurant.name}</strong>
                                  <small>
                                    {item.restaurant.category} ·{' '}
                                    {item.restaurant.address || '주소 정보 없음'}
                                  </small>
                                  <em>
                                    {item.analyzedDate}
                                    {item.daysElapsed !== null
                                      ? ` · ${item.daysElapsed}일 전`
                                      : ''}
                                  </em>
                                </span>
                              </button>
                            </li>
                          ))}
                        </ul>
                      )}
                    </section>
                  </div>
                )}
              </>
            )}
          </section>
        </aside>
      )}
      {activeSidePanel === 'ai' && (
        <aside className="restaurant-panel ai-panel" aria-label="AI 추천">
          <button
            type="button"
            className="panel-close-button"
            aria-label="AI 추천 닫기"
            onClick={() => setActiveSidePanel('search')}
          >
            <X aria-hidden="true" size={19} strokeWidth={2.2} />
          </button>

          <section className="bookmark-panel-body">
            <div className="bookmark-panel-header">
              <Sparkles aria-hidden="true" size={22} strokeWidth={2.2} />
              <div>
                <p>{aiRecommendState.page} 페이지</p>
                <h2>AI 추천</h2>
              </div>
            </div>
            <p className="ai-panel-description">
              가게별로 광고 가능성이 낮게 감지된 리뷰입니다.
            </p>
            {aiRecommendState.currentRegionLabel && (
              <div className="ai-current-region" aria-label="현재 위치 행정구역">
                <span>현재 위치</span>
                <strong>{aiRecommendState.currentRegionLabel}</strong>
              </div>
            )}
            <div className="ai-region-tabs" role="tablist" aria-label="추천 지역 범위">
              {AI_REGION_SCOPE_OPTIONS.map((regionScope) => (
                <button
                  type="button"
                  key={regionScope}
                  className={aiRegionScope === regionScope ? 'active' : ''}
                  disabled={aiRecommendState.isLoading}
                  onClick={() => changeAiRegionScope(regionScope)}
                >
                  {AI_REGION_SCOPE_LABELS[regionScope]}
                </button>
              ))}
            </div>
            {!aiRecommendState.currentRegionLabel && (
              <p className="ai-region-status">
                {currentPosition
                  ? '현재 위치를 확인하는 중입니다'
                  : '현재 위치를 확인하면 지역별 추천이 적용됩니다'}
              </p>
            )}

            {aiRecommendState.isLoading && aiRecommendState.items.length === 0 && (
              <div className="detail-state-card">
                <LoaderCircle
                  aria-hidden="true"
                  className="spinning-icon"
                  size={24}
                  strokeWidth={2.2}
                />
                <strong>AI 추천을 불러오는 중입니다</strong>
                <p>광고 가능성이 낮은 리뷰를 찾고 있어요.</p>
              </div>
            )}

            {aiRecommendState.errorMessage && aiRecommendState.items.length === 0 && (
              <div className="detail-state-card detail-state-error">
                <AlertCircle aria-hidden="true" size={24} strokeWidth={2.2} />
                <strong>AI 추천 목록을 불러오지 못했어요</strong>
                <p>{aiRecommendState.errorMessage}</p>
                <button
                  type="button"
                  className="detail-secondary-button"
                  onClick={() => loadAiRecommendations(aiRecommendState.page)}
                >
                  <RefreshCw aria-hidden="true" size={16} strokeWidth={2.2} />
                  다시 시도
                </button>
              </div>
            )}

            {!aiRecommendState.isLoading &&
              !aiRecommendState.errorMessage &&
              aiRecommendState.items.length === 0 && (
                <div className="bookmark-empty">
                  표시할 추천 데이터가 없습니다
                </div>
              )}

            {aiRecommendState.items.length > 0 && (
              <>
                <ul className="ai-recommend-list">
                  {aiRecommendState.items.map((item) => {
                    const restaurant = aiRecommendToRestaurant(item)
                    const placeName =
                      item.placeName || item.name || '이름 없는 장소'

                    return (
                      <li key={item.id}>
                        <article className="ai-recommend-card">
                          <div className="ai-card-heading">
                            <strong>{placeName}</strong>
                            <span>광고 가능성 {formatAdScore(item.adScore)}</span>
                          </div>
                          <h3>{item.reviewTitle || '제목 없는 리뷰'}</h3>
                          {item.reviewDescription && (
                            <p>{item.reviewDescription}</p>
                          )}
                          <small>
                            {[item.bloggerName, item.postDate]
                              .filter(Boolean)
                              .join(' · ') || '블로그 리뷰'}
                          </small>
                          <div className="ai-card-actions">
                            <button
                              type="button"
                              disabled={!restaurant}
                              onClick={() => focusAiRecommendation(item)}
                            >
                              <MapPin
                                aria-hidden="true"
                                size={15}
                                strokeWidth={2.2}
                              />
                              위치 보기
                            </button>
                            <button
                              type="button"
                              disabled={!item.reviewUrl}
                              onClick={() => {
                                if (item.reviewUrl) {
                                  window.open(
                                    item.reviewUrl,
                                    '_blank',
                                    'noopener,noreferrer',
                                  )
                                }
                              }}
                            >
                              <ExternalLink
                                aria-hidden="true"
                                size={15}
                                strokeWidth={2.2}
                              />
                              리뷰 열기
                            </button>
                          </div>
                        </article>
                      </li>
                    )
                  })}
                </ul>

                <div className="ai-pagination">
                  <button
                    type="button"
                    disabled={aiRecommendState.page <= 1 || aiRecommendState.isLoading}
                    onClick={() => loadAiRecommendations(aiRecommendState.page - 1)}
                  >
                    이전 10개
                  </button>
                  <button
                    type="button"
                    disabled={!aiRecommendState.hasNext || aiRecommendState.isLoading}
                    onClick={() => loadAiRecommendations(aiRecommendState.page + 1)}
                  >
                    {aiRecommendState.isLoading ? '불러오는 중' : '다음 10개'}
                  </button>
                </div>
              </>
            )}
          </section>
        </aside>
      )}
      {activeSidePanel === 'settings' && (
        <aside className="restaurant-panel settings-panel" aria-label="설정">
          <button
            type="button"
            className="panel-close-button"
            aria-label="설정 닫기"
            onClick={() => setActiveSidePanel('search')}
          >
            <X aria-hidden="true" size={19} strokeWidth={2.2} />
          </button>

          <section className="bookmark-panel-body settings-panel-body">
            <div className="bookmark-panel-header settings-panel-header">
              <Settings aria-hidden="true" size={22} strokeWidth={2.2} />
              <div>
                <p>Account</p>
                <h2>설정</h2>
              </div>
            </div>

            {isTemporaryAdmin ? (
              <div className="settings-card">
                <div className="settings-card-heading">
                  <UserRound aria-hidden="true" size={19} strokeWidth={2.2} />
                  <div>
                    <strong>임시 관리자 로그인</strong>
                    <span>Google 로그인 사용자가 아니어서 결제 설정은 비활성화됩니다.</span>
                  </div>
                </div>
                <div className="settings-disabled-actions">
                  <button type="button" disabled>
                    프리미엄 설정
                  </button>
                  <button type="button" disabled>
                    1,000 코인 충전
                  </button>
                </div>
                <button
                  type="button"
                  className="settings-logout-button"
                  onClick={signOut}
                >
                  <LogOut aria-hidden="true" size={16} strokeWidth={2.2} />
                  로그아웃
                </button>
              </div>
            ) : (
              <>
                {userProfileState.isLoading && !userProfileState.profile && (
                  <div className="detail-state-card">
                    <LoaderCircle
                      aria-hidden="true"
                      className="spinning-icon"
                      size={24}
                      strokeWidth={2.2}
                    />
                    <strong>계정 정보를 불러오는 중입니다</strong>
                    <p>로그인된 이메일 기준으로 설정을 확인하고 있어요.</p>
                  </div>
                )}

                {userProfileState.errorMessage && !userProfileState.profile && (
                  <div className="detail-state-card detail-state-error">
                    <AlertCircle aria-hidden="true" size={24} strokeWidth={2.2} />
                    <strong>계정 정보를 불러오지 못했어요</strong>
                    <p>{userProfileState.errorMessage}</p>
                    <button
                      type="button"
                      className="detail-secondary-button"
                      onClick={loadUserProfile}
                    >
                      <RefreshCw aria-hidden="true" size={16} strokeWidth={2.2} />
                      다시 시도
                    </button>
                  </div>
                )}

                {userProfileState.profile && (
                  <>
                    <div className="settings-card">
                      <div className="settings-card-heading">
                        <UserRound
                          aria-hidden="true"
                          size={19}
                          strokeWidth={2.2}
                        />
                        <div>
                          <strong>{userProfileState.profile.email}</strong>
                          <span>
                            {userProfileState.profile.premium === 1
                              ? '프리미엄 사용자'
                              : '일반 사용자'}
                          </span>
                        </div>
                      </div>

                      <div className="settings-stat-grid">
                        <div>
                          <span>Coin</span>
                          <strong>
                            {userProfileState.profile.coin.toLocaleString()}
                          </strong>
                        </div>
                        <div>
                          <span>Free</span>
                          <strong>{userProfileState.profile.freecount}</strong>
                        </div>
                        <div>
                          <span>Premium</span>
                          <strong>{userProfileState.profile.premiumcount}</strong>
                        </div>
                      </div>
                    </div>

                    <div className="settings-card">
                      <div className="settings-card-heading">
                        <Crown aria-hidden="true" size={19} strokeWidth={2.2} />
                        <div>
                          <strong>프리미엄</strong>
                          <span>현재 계정의 premium 값을 1 또는 0으로 저장합니다.</span>
                        </div>
                      </div>
                      <button
                        type="button"
                        className="settings-primary-button"
                        disabled={userProfileState.isSaving}
                        onClick={toggleUserPremium}
                      >
                        {userProfileState.profile.premium === 1
                          ? '프리미엄 해제'
                          : '프리미엄 설정'}
                      </button>
                    </div>

                    <div className="settings-card">
                      <div className="settings-card-heading">
                        <Coins aria-hidden="true" size={19} strokeWidth={2.2} />
                        <div>
                          <strong>코인 충전</strong>
                          <span>테스트용 충전 버튼입니다.</span>
                        </div>
                      </div>
                      <div className="settings-coin-buttons">
                        {[1000, 2000, 3000].map((amount) => (
                          <button
                            type="button"
                            key={amount}
                            disabled={userProfileState.isSaving}
                            onClick={() => chargeCoins(amount)}
                          >
                            {amount.toLocaleString()}
                          </button>
                        ))}
                      </div>
                    </div>

                    {userProfileState.errorMessage && (
                      <p className="settings-error-message">
                        {userProfileState.errorMessage}
                      </p>
                    )}
                  </>
                )}

                {!userProfileState.isLoading &&
                  !userProfileState.profile &&
                  !userProfileState.errorMessage && (
                    <div className="bookmark-empty">
                      Google 로그인 정보를 확인할 수 없습니다
                    </div>
                  )}

                <button
                  type="button"
                  className="settings-logout-button"
                  onClick={signOut}
                >
                  <LogOut aria-hidden="true" size={16} strokeWidth={2.2} />
                  로그아웃
                </button>
              </>
            )}
          </section>
        </aside>
      )}
        </>
      )}
      </section>
      <section className="map-view" aria-label="지도">
      <div ref={mapContainerRef} className="map-container" />
      {loadState === 'loading' && (
        <div className="map-status">카카오맵을 불러오는 중입니다</div>
      )}
      {loadState === 'error' && (
        <div className="map-status map-status-error">{errorMessage}</div>
      )}
      {loadState === 'ready' && placesErrorMessage && (
        <div className="map-status map-status-error">{placesErrorMessage}</div>
      )}
      <nav className="map-tool-rail" aria-label="지도 메뉴">
        <div className="map-tool-brand" aria-hidden="true">
          <img src={appLogoUrl} alt="" />
        </div>
        <button
          type="button"
          className="map-tool-button"
          aria-label="장소 검색"
          onClick={() => {
            setSelectedRestaurant(null)
            setActiveSidePanel('search')
          }}
        >
          <Search aria-hidden="true" size={20} strokeWidth={2.2} />
        </button>
        <button
          type="button"
          className="map-tool-button"
          aria-label="내 위치로 이동"
          onClick={focusCurrentLocationOnMap}
        >
          <LocateFixed aria-hidden="true" size={20} strokeWidth={2.2} />
        </button>
        <button
          type="button"
          className="map-tool-button"
          aria-label="북마크"
          onClick={() => {
            setSelectedRestaurant(null)
            setActiveSidePanel((current) =>
              current === 'bookmarks' ? 'search' : 'bookmarks',
            )
          }}
        >
          <Bookmark aria-hidden="true" size={20} strokeWidth={2.2} />
        </button>
        <button
          type="button"
          className="map-tool-button"
          aria-label="최근분석"
          onClick={openRecentPanel}
        >
          <Clock aria-hidden="true" size={20} strokeWidth={2.2} />
        </button>
        <button
          type="button"
          className="map-tool-button"
          aria-label="AI 추천"
          onClick={openAiPanel}
        >
          <Sparkles aria-hidden="true" size={20} strokeWidth={2.2} />
        </button>
        <button
          type="button"
          className="map-tool-button"
          aria-label="설정"
          onClick={openSettingsPanel}
        >
          <Settings aria-hidden="true" size={20} strokeWidth={2.2} />
        </button>
      </nav>
      {toastMessage && <div className="map-toast">{toastMessage}</div>}
      </section>
    </main>
  )
}

export default App
