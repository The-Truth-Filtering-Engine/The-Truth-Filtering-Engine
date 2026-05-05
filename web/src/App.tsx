import {
  AlertCircle,
  ArrowLeft,
  Bookmark,
  BookmarkCheck,
  Clock,
  ExternalLink,
  Info,
  LocateFixed,
  LoaderCircle,
  MapPin,
  Navigation,
  Phone,
  RefreshCw,
  Settings,
  Share2,
  Sparkles,
  X,
} from 'lucide-react'
import { useEffect, useRef, useState } from 'react'

type LoadState = 'loading' | 'ready' | 'error'

type MapPoint = {
  latitude: number
  longitude: number
}

type Restaurant = {
  id: string
  name: string
  address: string
  category: string
  distance: number
  phone: string
  link: string
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
  latitude: number | null
  longitude: number | null
  placeUrl: string
  phone: string
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

type KakaoLatLng = {
  getLat: () => number
  getLng: () => number
}

type KakaoBounds = {
  getSouthWest: () => KakaoLatLng
  getNorthEast: () => KakaoLatLng
}

type KakaoMap = {
  getBounds: () => KakaoBounds
  getCenter: () => KakaoLatLng
  getLevel: () => number
  relayout: () => void
  setCenter: (latLng: KakaoLatLng) => void
  setLevel: (level: number) => void
}

type KakaoCustomOverlay = {
  setMap: (map: KakaoMap | null) => void
  setPosition: (latLng: KakaoLatLng) => void
}

type KakaoMaps = {
  LatLng: new (latitude: number, longitude: number) => KakaoLatLng
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
const KAKAO_SDK_ID = 'kakao-map-sdk'
const INITIAL_CENTER = { latitude: 37.5245, longitude: 127.037 }
const INITIAL_LEVEL = 4
const FOCUSED_LEVEL = 1
const VIEWPORT_DEBOUNCE_MS = 600
const REFRESH_DISTANCE_METERS = 150
const NEARBY_PLACE_DISPLAY_COUNT = 30
const BOOKMARK_STORAGE_KEY = 'bookmarked_restaurants'
const AI_REGION_SCOPE_LABELS: Record<AiRegionScope, string> = {
  si: '시',
  gu: '구',
  dong: '동',
}
const AI_REGION_SCOPE_OPTIONS: AiRegionScope[] = ['si', 'gu', 'dong']

let kakaoMapsLoader: Promise<KakaoMaps> | null = null

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

function isCafe(restaurant: Restaurant) {
  const normalizedCategory = restaurant.category.toLowerCase()
  return restaurant.category.includes('카페') || normalizedCategory.includes('cafe')
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
      name?: string
      address?: string
      category?: string
      distance?: number | string
      phone?: string
      link?: string
      lat?: number | string
      lng?: number | string
    }>
  }

  return (data.restaurants ?? [])
    .map((item) => ({
      id: item.id?.toString() ?? '',
      name: item.name?.toString() ?? '',
      address: item.address?.toString() ?? '',
      category: item.category?.toString() ?? '음식점',
      distance: Number(item.distance ?? 0),
      phone: item.phone?.toString() ?? '',
      link: item.link?.toString() ?? '',
      latitude: Number(item.lat),
      longitude: Number(item.lng),
    }))
    .filter(
      (restaurant) =>
        restaurant.id &&
        restaurant.name &&
        Number.isFinite(restaurant.latitude) &&
        Number.isFinite(restaurant.longitude) &&
        Number.isFinite(restaurant.distance),
    )
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
    url: cleanText(item.review_url),
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

async function fetchDetailJson(path: string, signal: AbortSignal) {
  const response = await fetch(`${BACKEND_BASE_URL}${path}`, { signal })
  if (!response.ok) {
    throw new Error(`상세 데이터 요청 실패: ${response.status}`)
  }
  return (await response.json()) as {
    reviews?: Record<string, unknown>[]
  }
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
    name: item.placeName || item.name || '이름 없는 장소',
    address: item.address,
    category: item.category || '음식점',
    distance: 0,
    phone: item.phone,
    link: item.placeUrl,
    latitude: item.latitude,
    longitude: item.longitude,
  }
}

function formatAdScore(adScore: number) {
  if (!Number.isFinite(adScore)) return '정보 없음'
  return `${Math.round(Math.max(0, Math.min(1, adScore)) * 100)}%`
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
    name,
    address: item.address?.toString() ?? '',
    category: item.category?.toString() ?? '음식점',
    distance: Number(item.distance ?? 0),
    phone: item.phone?.toString() ?? '',
    link: (item.link ?? item.placeUrl)?.toString() ?? '',
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

    return decoded
      .map((item) => normalizeRestaurant(item))
      .filter((restaurant): restaurant is Restaurant => Boolean(restaurant))
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

function App() {
  const mapContainerRef = useRef<HTMLDivElement>(null)
  const kakaoMapsRef = useRef<KakaoMaps | null>(null)
  const kakaoMapRef = useRef<KakaoMap | null>(null)
  const currentLocationOverlayRef = useRef<KakaoCustomOverlay | null>(null)
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
  const [activeSidePanel, setActiveSidePanel] = useState<
    'restaurant' | 'bookmarks' | 'detail' | 'ai' | null
  >(
    null,
  )
  const [detailState, setDetailState] = useState<DetailState>('idle')
  const [detailData, setDetailData] = useState<DetailData | null>(null)
  const [detailErrorMessage, setDetailErrorMessage] = useState('')
  const [reviewSort, setReviewSort] = useState<'real' | 'latest'>('real')
  const [currentPosition, setCurrentPosition] = useState<MapPoint | null>(null)
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
  const [toastMessage, setToastMessage] = useState('')
  const bookmarkedIds = bookmarkedRestaurants.map((restaurant) => restaurant.id)
  const detailRequestIdRef = useRef(0)

  function showToast(message: string) {
    setToastMessage(message)
    window.setTimeout(() => setToastMessage(''), 1800)
  }

  async function copyToClipboard(value: string, successMessage: string) {
    try {
      await navigator.clipboard.writeText(value)
      showToast(successMessage)
    } catch {
      showToast('클립보드 복사에 실패했습니다')
    }
  }

  function toggleBookmark(restaurant: Restaurant) {
    setBookmarkedRestaurants((previous) => {
      const bookmarked = previous.some((item) => item.id === restaurant.id)
      const next = bookmarked
        ? previous.filter((item) => item.id !== restaurant.id)
        : [restaurant, ...previous]

      saveBookmarkedRestaurants(next)
      showToast(bookmarked ? '북마크에서 해제되었습니다' : '북마크에 저장했습니다')
      return next
    })
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
    const query = encodeURIComponent(restaurant.name)

    setDetailErrorMessage('')
    setDetailData(null)
    setReviewSort('real')
    setDetailState(forceFresh ? 'analyzing' : 'loading')

    try {
      let detailJson: Awaited<ReturnType<typeof fetchDetailJson>>

      if (!forceFresh) {
        const cached = await fetchDetailJson(
          `/api/search/cached?query=${query}`,
          controller.signal,
        )
        if (requestId !== detailRequestIdRef.current) return

        if ((cached.reviews ?? []).length > 0) {
          detailJson = cached
        } else {
          setDetailState('analyzing')
          detailJson = await fetchDetailJson(
            `/api/search?query=${query}&mode=model`,
            controller.signal,
          )
        }
      } else {
        detailJson = await fetchDetailJson(
          `/api/search?query=${query}&mode=model`,
          controller.signal,
        )
      }

      if (requestId !== detailRequestIdRef.current) return

      const reviews = (detailJson.reviews ?? []).map(parseBlogReview)
      if (reviews.length === 0) {
        setDetailState('noData')
        return
      }

      setDetailData({
        reviews,
        keywords: buildKeywords(reviews),
      })
      setDetailState('loaded')
    } catch (error) {
      if (requestId !== detailRequestIdRef.current) return
      setDetailErrorMessage(
        error instanceof Error
          ? error.message
          : '상세 데이터를 불러오지 못했습니다',
      )
      setDetailState('error')
    }
  }

  function openDetailPanel(restaurant: Restaurant, forceFresh = false) {
    setSelectedRestaurant(restaurant)
    setActiveSidePanel('detail')
    loadRestaurantDetail(restaurant, forceFresh)
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
      const next = current === 'ai' ? null : 'ai'
      if (next === 'ai' && !aiRecommendState.hasLoaded) {
        loadAiRecommendations(1)
      }
      return next
    })
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
      let restaurantOverlays: KakaoCustomOverlay[] = []
      let viewportSearchTimer = 0
      let viewportSearchRequestId = 0
      let lastSearchedCenter: MapPoint | null = null
      let lastSearchedLevel: number | null = null

      function clearRestaurantOverlays() {
        for (const overlay of restaurantOverlays) {
          overlay.setMap(null)
        }
        restaurantOverlays = []
      }

      function syncRestaurantOverlays(
        kakaoMaps: KakaoMaps,
        map: KakaoMap,
        restaurants: Restaurant[],
      ) {
        clearRestaurantOverlays()

        restaurantOverlays = restaurants.map((restaurant) => {
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

      function shouldRefreshViewport(center: MapPoint, level: number) {
        if (!lastSearchedCenter || lastSearchedLevel === null) return true

        return (
          distanceMeters(center, lastSearchedCenter) >= REFRESH_DISTANCE_METERS ||
          level !== lastSearchedLevel
        )
      }

      function scheduleViewportSearch(kakaoMaps: KakaoMaps, map: KakaoMap) {
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

            syncRestaurantOverlays(kakaoMaps, map, restaurants)
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
        kakaoMaps.event.addListener(map, 'idle', () =>
          scheduleViewportSearch(kakaoMaps, map),
        )
        kakaoMaps.event.addListener(map, 'click', () => {
          setSelectedRestaurant(null)
          setActiveSidePanel(null)
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

        scheduleViewportSearch(kakaoMaps, map)
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

  return (
    <main className="map-page">
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
      {selectedRestaurant && activeSidePanel === 'restaurant' && (
        <aside className="restaurant-panel" aria-label="선택한 가게 정보">
          <button
            type="button"
            className="panel-close-button"
            aria-label="가게 정보 닫기"
            onClick={() => {
              setSelectedRestaurant(null)
              setActiveSidePanel(null)
            }}
          >
            <X aria-hidden="true" size={19} strokeWidth={2.2} />
          </button>

          <div className="restaurant-panel-hero">
            <div className="restaurant-thumbnail" aria-hidden="true">
              {isCafe(selectedRestaurant) ? '☕' : '🍽'}
            </div>
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
                {bookmarkedIds.includes(selectedRestaurant.id) ? (
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
              onClick={() => openDetailPanel(selectedRestaurant)}
            >
              <Info aria-hidden="true" size={18} strokeWidth={2.2} />
              상세 보기
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
                setActiveSidePanel(null)
              }}
            >
              <X aria-hidden="true" size={19} strokeWidth={2.2} />
            </button>
          </div>

          <section className="detail-panel-body">
            <div className="detail-restaurant-card">
              <div className="bookmark-thumb detail-thumb" aria-hidden="true">
                {isCafe(selectedRestaurant) ? '☕' : '🍽'}
              </div>
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
                {bookmarkedIds.includes(selectedRestaurant.id) ? (
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
                      onClick={() => setReviewSort('real')}
                    >
                      진성순
                    </button>
                    <button
                      type="button"
                      className={reviewSort === 'latest' ? 'active' : ''}
                      onClick={() => setReviewSort('latest')}
                    >
                      최신순
                    </button>
                  </div>
                  <ul className="review-list">
                    {sortedDetailReviews.map((review) => (
                      <li key={`${review.id}-${review.url}`}>
                        <button
                          type="button"
                          className="review-card"
                          onClick={() => {
                            if (review.url) {
                              window.open(review.url, '_blank', 'noopener,noreferrer')
                            } else {
                              showToast('열 수 있는 리뷰 링크가 없습니다')
                            }
                          }}
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
                          <span className="review-open">
                            원문 보기
                            <ExternalLink
                              aria-hidden="true"
                              size={13}
                              strokeWidth={2.2}
                            />
                          </span>
                        </button>
                      </li>
                    ))}
                  </ul>
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
            onClick={() => setActiveSidePanel(null)}
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
                  <li key={restaurant.id}>
                    <button
                      type="button"
                      className="bookmark-list-item"
                      onClick={() => focusRestaurantOnMap(restaurant)}
                    >
                      <span className="bookmark-thumb" aria-hidden="true">
                        {isCafe(restaurant) ? '☕' : '🍽'}
                      </span>
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
                      onClick={() => toggleBookmark(restaurant)}
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
      {activeSidePanel === 'ai' && (
        <aside className="restaurant-panel ai-panel" aria-label="AI 추천">
          <button
            type="button"
            className="panel-close-button"
            aria-label="AI 추천 닫기"
            onClick={() => setActiveSidePanel(null)}
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
      <nav className="map-tool-rail" aria-label="지도 메뉴">
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
              current === 'bookmarks' ? null : 'bookmarks',
            )
          }}
        >
          <Bookmark aria-hidden="true" size={20} strokeWidth={2.2} />
        </button>
        <button
          type="button"
          className="map-tool-button"
          aria-label="AI 추천"
          onClick={openAiPanel}
        >
          <Sparkles aria-hidden="true" size={20} strokeWidth={2.2} />
        </button>
        <button type="button" className="map-tool-button" aria-label="설정">
          <Settings aria-hidden="true" size={20} strokeWidth={2.2} />
        </button>
      </nav>
      {toastMessage && <div className="map-toast">{toastMessage}</div>}
    </main>
  )
}

export default App
