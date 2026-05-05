import { useEffect, useRef, useState } from 'react'

type LoadState = 'loading' | 'ready' | 'error'

type MapPoint = {
  latitude: number
  longitude: number
}

type Restaurant = {
  id: string
  name: string
  category: string
  latitude: number
  longitude: number
}

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
}

type KakaoCustomOverlay = {
  setMap: (map: KakaoMap | null) => void
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
const VIEWPORT_DEBOUNCE_MS = 600
const REFRESH_DISTANCE_METERS = 150

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

function createRestaurantMarker(restaurant: Restaurant) {
  const marker = document.createElement('button')
  marker.type = 'button'
  marker.className = 'restaurant-marker'
  marker.title = restaurant.name
  marker.textContent = isCafe(restaurant) ? '☕' : '🍽'
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
    display: '10',
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
      category?: string
      lat?: number | string
      lng?: number | string
    }>
  }

  return (data.restaurants ?? [])
    .map((item) => ({
      id: item.id?.toString() ?? '',
      name: item.name?.toString() ?? '',
      category: item.category?.toString() ?? '음식점',
      latitude: Number(item.lat),
      longitude: Number(item.lng),
    }))
    .filter(
      (restaurant) =>
        restaurant.id &&
        restaurant.name &&
        Number.isFinite(restaurant.latitude) &&
        Number.isFinite(restaurant.longitude),
    )
}

function App() {
  const mapContainerRef = useRef<HTMLDivElement>(null)
  const [loadState, setLoadState] = useState<LoadState>('loading')
  const [errorMessage, setErrorMessage] = useState('')
  const [placesErrorMessage, setPlacesErrorMessage] = useState('')

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
            content: createRestaurantMarker(restaurant),
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

        setLoadState('ready')
        kakaoMaps.event.addListener(map, 'idle', () =>
          scheduleViewportSearch(kakaoMaps, map),
        )

        for (const delay of [100, 300, 700]) {
          window.setTimeout(() => {
            if (!canceled) map.relayout()
          }, delay)
        }

        try {
          const position = await getCurrentPosition()
          if (canceled) return

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
    </main>
  )
}

export default App
