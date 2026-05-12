import { cleanText, cleanImageUrl, formatReviewDate } from './format'

export type Restaurant = {
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

export type AiRecommendItem = {
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

export type RecentAnalysisRestaurant = Omit<Restaurant, 'latitude' | 'longitude'> & {
  latitude: number | null
  longitude: number | null
}

export type RecentAnalysisItem = {
  storeId: string
  analyzedDate: string
  daysElapsed: number | null
  remainingFreeDays: number
  restaurant: RecentAnalysisRestaurant
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

export function isCafe(restaurant: Pick<Restaurant, 'category'>) {
  const normalizedCategory = restaurant.category.toLowerCase()
  return restaurant.category.includes('카페') || normalizedCategory.includes('cafe')
}

export function primaryRestaurantCategory(
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

export function restaurantThumbnailKey(
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

export function restaurantThumbnailSrc(
  restaurant: Pick<Restaurant, 'category' | 'categoryName' | 'categoryGroupName' | 'imageUrl'>,
) {
  const imageUrl = cleanImageUrl(restaurant.imageUrl)
  if (imageUrl) return imageUrl
  return `${CATEGORY_THUMBNAIL_BASE}/${restaurantThumbnailKey(restaurant)}.png`
}

export function getRestaurantStoreId(restaurant: Pick<Restaurant, 'id' | 'storeId'>) {
  return restaurant.storeId?.trim() || restaurant.id.trim()
}

export function parseRestaurantPayloadItem(item: {
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

export function normalizeRestaurant(value: unknown): Restaurant | null {
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

export function dedupeBookmarkRestaurants(restaurants: Restaurant[]) {
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

export function restaurantToBookmarkStore(restaurant: Restaurant) {
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

export function aiRecommendToRestaurant(item: AiRecommendItem): Restaurant | null {
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

export function parseAiRecommendItem(item: Record<string, unknown>): AiRecommendItem {
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

export function recentAnalysisToRestaurant(item: RecentAnalysisItem): Restaurant | null {
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
