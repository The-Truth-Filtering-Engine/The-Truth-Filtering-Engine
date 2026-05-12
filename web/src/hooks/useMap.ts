import { useEffect, useRef, useState } from 'react'
import {
  fetchKakaoJsKey,
  loadKakaoMaps,
  getCurrentPosition,
  createCurrentLocationMarker,
  createRestaurantMarker,
  pointFromLatLng,
  calculateViewportRadius,
  distanceMeters,
  type KakaoMap,
  type KakaoMaps,
  type KakaoCustomOverlay,
  type MapPoint,
} from '../lib/kakao'
import { fetchNearbyRestaurants } from '../api/places'
import { type Restaurant } from '../lib/restaurant'

const INITIAL_CENTER: MapPoint = { latitude: 37.5245, longitude: 127.037 }
const INITIAL_LEVEL = 4
const FOCUSED_LEVEL = 1
const VIEWPORT_DEBOUNCE_MS = 600
const REFRESH_DISTANCE_METERS = 150

type LoadState = 'loading' | 'ready' | 'error'

export type UseMapReturn = {
  mapContainerRef: React.RefObject<HTMLDivElement | null>
  loadState: LoadState
  errorMessage: string
  placesErrorMessage: string
  currentPosition: MapPoint | null
  focusRestaurantOnMap: (restaurant: Restaurant) => void
  focusCurrentLocationOnMap: () => Promise<void>
  displayRestaurantsOnMap: (restaurants: Restaurant[], options?: { preserveViewport?: boolean }) => void
  fitMapToRestaurants: (restaurants: Restaurant[]) => void
  clearRestaurantOverlays: () => void
  getSearchCenter: () => MapPoint
  viewportRestaurantsRef: React.MutableRefObject<Restaurant[]>
  searchModeRef: React.MutableRefObject<boolean>
  bookmarkFocusModeRef: React.MutableRefObject<boolean>
}

export function useMap(
  onSelectRestaurant: (restaurant: Restaurant) => void,
  showToast: (message: string) => void,
): UseMapReturn {
  const mapContainerRef = useRef<HTMLDivElement>(null)
  const kakaoMapsRef = useRef<KakaoMaps | null>(null)
  const kakaoMapRef = useRef<KakaoMap | null>(null)
  const currentLocationOverlayRef = useRef<KakaoCustomOverlay | null>(null)
  const restaurantOverlaysRef = useRef<KakaoCustomOverlay[]>([])
  const viewportRestaurantsRef = useRef<Restaurant[]>([])
  const searchModeRef = useRef(false)
  const bookmarkFocusModeRef = useRef(false)

  const [loadState, setLoadState] = useState<LoadState>('loading')
  const [errorMessage, setErrorMessage] = useState('')
  const [placesErrorMessage, setPlacesErrorMessage] = useState('')
  const [currentPosition, setCurrentPosition] = useState<MapPoint | null>(null)

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
      viewportRestaurantsRef.current = searchModeRef.current
        ? viewportRestaurantsRef.current
        : restaurants
    }

    const kakaoMaps = kakaoMapsRef.current
    const map = kakaoMapRef.current
    if (!kakaoMaps || !map) return

    clearRestaurantOverlays()
    restaurantOverlaysRef.current = restaurants.map((restaurant) => {
      const overlay = new kakaoMaps.CustomOverlay({
        content: createRestaurantMarker(restaurant, () => onSelectRestaurant(restaurant)),
        position: new kakaoMaps.LatLng(restaurant.latitude, restaurant.longitude),
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
      map.setCenter(new kakaoMaps.LatLng(restaurants[0].latitude, restaurants[0].longitude))
      map.setLevel(FOCUSED_LEVEL)
      return
    }

    const bounds = new kakaoMaps.LatLngBounds()
    for (const restaurant of restaurants) {
      bounds.extend(new kakaoMaps.LatLng(restaurant.latitude, restaurant.longitude))
    }
    map.setBounds(bounds)
  }

  function getSearchCenter(): MapPoint {
    const map = kakaoMapRef.current
    if (map) return pointFromLatLng(map.getCenter())
    return currentPosition ?? INITIAL_CENTER
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
      const latLng = new kakaoMaps.LatLng(nextPosition.latitude, nextPosition.longitude)

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
              error instanceof Error ? error.message : '주변 장소를 불러오지 못했습니다',
            )
          }
        }, VIEWPORT_DEBOUNCE_MS)
      }

      try {
        const kakaoJsKey = await fetchKakaoJsKey()
        const kakaoMaps = await loadKakaoMaps(kakaoJsKey)

        if (canceled || !mapContainerRef.current) return

        const center = new kakaoMaps.LatLng(INITIAL_CENTER.latitude, INITIAL_CENTER.longitude)
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
          onSelectRestaurant(null as unknown as Restaurant)
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
          error instanceof Error ? error.message : '카카오맵을 불러오지 못했습니다',
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

  return {
    mapContainerRef,
    loadState,
    errorMessage,
    placesErrorMessage,
    currentPosition,
    focusRestaurantOnMap,
    focusCurrentLocationOnMap,
    displayRestaurantsOnMap,
    fitMapToRestaurants,
    clearRestaurantOverlays,
    getSearchCenter,
    viewportRestaurantsRef,
    searchModeRef,
    bookmarkFocusModeRef,
  }
}
