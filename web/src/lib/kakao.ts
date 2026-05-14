import { KAKAO_JS_KEY } from '../config'

export type MapPoint = {
  latitude: number
  longitude: number
}

export type KakaoLatLng = {
  getLat: () => number
  getLng: () => number
}

export type KakaoBounds = {
  getSouthWest: () => KakaoLatLng
  getNorthEast: () => KakaoLatLng
}

export type KakaoLatLngBounds = {
  extend: (latLng: KakaoLatLng) => void
}

export type KakaoMap = {
  getBounds: () => KakaoBounds
  getCenter: () => KakaoLatLng
  getLevel: () => number
  relayout: () => void
  setBounds: (bounds: KakaoLatLngBounds) => void
  setCenter: (latLng: KakaoLatLng) => void
  setLevel: (level: number) => void
}

export type KakaoCustomOverlay = {
  setMap: (map: KakaoMap | null) => void
  setPosition: (latLng: KakaoLatLng) => void
}

export type KakaoMaps = {
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

const KAKAO_SDK_ID = 'kakao-map-sdk'
let kakaoMapsLoader: Promise<KakaoMaps> | null = null

export function loadKakaoMaps() {
  if (kakaoMapsLoader) return kakaoMapsLoader
  if (!KAKAO_JS_KEY) {
    return Promise.reject(new Error('VITE_KAKAO_JS_KEY를 확인해 주세요'))
  }

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
    script.src = `https://dapi.kakao.com/v2/maps/sdk.js?appkey=${encodeURIComponent(KAKAO_JS_KEY)}&autoload=false`
    script.onload = finishLoading
    script.onerror = () => reject(new Error('Kakao 지도 SDK 로드 실패'))
    document.head.appendChild(script)
  })

  return kakaoMapsLoader
}

export function getCurrentPosition() {
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

export function createCurrentLocationMarker() {
  const outer = document.createElement('div')
  outer.className = 'current-location-marker'

  const inner = document.createElement('div')
  inner.className = 'current-location-dot'

  outer.appendChild(inner)
  return outer
}

export function createRestaurantMarker(
  restaurant: { name: string; category: string },
  onClick: () => void,
) {
  const marker = document.createElement('button')
  marker.type = 'button'
  marker.className = 'restaurant-marker'
  marker.title = restaurant.name
  marker.textContent = isCafeCategory(restaurant.category) ? '☕' : '🍽'
  marker.addEventListener('click', (event) => {
    event.preventDefault()
    event.stopPropagation()
    onClick()
  })
  return marker
}

function isCafeCategory(category: string) {
  const normalized = category.toLowerCase()
  return category.includes('카페') || normalized.includes('cafe')
}

export function pointFromLatLng(latLng: KakaoLatLng): MapPoint {
  return {
    latitude: latLng.getLat(),
    longitude: latLng.getLng(),
  }
}

export function toRadians(degrees: number) {
  return (degrees * Math.PI) / 180
}

export function distanceMeters(a: MapPoint, b: MapPoint) {
  const earthRadiusMeters = 6_371_000
  const lat1 = toRadians(a.latitude)
  const lat2 = toRadians(b.latitude)
  const dLat = toRadians(b.latitude - a.latitude)
  const dLng = toRadians(b.longitude - a.longitude)
  const h =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) * Math.sin(dLng / 2)
  const c = 2 * Math.atan2(Math.sqrt(h), Math.sqrt(1 - h))
  return earthRadiusMeters * c
}

export function calculateViewportRadius(map: KakaoMap) {
  const center = pointFromLatLng(map.getCenter())
  const bounds = map.getBounds()
  const southWest = pointFromLatLng(bounds.getSouthWest())
  const northEast = pointFromLatLng(bounds.getNorthEast())
  const northWest = { latitude: northEast.latitude, longitude: southWest.longitude }
  const southEast = { latitude: southWest.latitude, longitude: northEast.longitude }
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
