import { BACKEND_BASE_URL } from '../config'
import { type MapPoint } from '../lib/kakao'
import { parseRestaurantPayloadItem, type Restaurant } from '../lib/restaurant'

const NEARBY_PLACE_DISPLAY_COUNT = 30
const SEARCH_RADIUS_METERS = 5000
const SEARCH_PLACE_DISPLAY_COUNT = 30

type RestaurantPayloadItem = {
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
}

function isValidRestaurant(restaurant: Restaurant) {
  return (
    restaurant.id &&
    restaurant.name &&
    Number.isFinite(restaurant.latitude) &&
    Number.isFinite(restaurant.longitude) &&
    Number.isFinite(restaurant.distance)
  )
}

export async function fetchNearbyRestaurants(center: MapPoint, radius: number) {
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

  const data = (await response.json()) as { restaurants?: RestaurantPayloadItem[] }

  return (data.restaurants ?? []).map(parseRestaurantPayloadItem).filter(isValidRestaurant)
}

export async function fetchSearchRestaurants(query: string, center: MapPoint) {
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

  const data = (await response.json()) as { restaurants?: RestaurantPayloadItem[] }

  return (data.restaurants ?? []).map(parseRestaurantPayloadItem).filter(isValidRestaurant)
}
