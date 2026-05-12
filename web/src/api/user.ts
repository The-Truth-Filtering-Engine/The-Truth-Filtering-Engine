import { BACKEND_BASE_URL } from '../config'
import { cleanText } from '../lib/format'
import {
  normalizeRestaurant,
  dedupeBookmarkRestaurants,
  restaurantToBookmarkStore,
  getRestaurantStoreId,
  type Restaurant,
  type RecentAnalysisItem,
  type RecentAnalysisRestaurant,
} from '../lib/restaurant'

export type UserProfile = {
  email: string
  premium: number
  coin: number
  freecount: number
  premiumcount: number
  store: unknown
  bookmark: unknown
}

export type UserBookmarks = {
  storeIds: string[]
  restaurants: Restaurant[]
}

export type RecentAnalyses = {
  today: string
  freeItems: RecentAnalysisItem[]
  expiredItems: RecentAnalysisItem[]
}

async function readErrorMessage(response: Response) {
  try {
    const data = (await response.json()) as { detail?: unknown }
    return cleanText(data.detail) || `요청 실패: ${response.status}`
  } catch {
    return `요청 실패: ${response.status}`
  }
}

function parseProfileNumber(value: unknown) {
  const parsed = Number(value ?? 0)
  return Number.isFinite(parsed) ? parsed : 0
}

export function parseUserProfile(item: Record<string, unknown>): UserProfile {
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

export function parseUserBookmarks(item: Record<string, unknown>): UserBookmarks {
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

  return { storeIds, restaurants }
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

export async function fetchUserProfile(accessToken: string) {
  const response = await fetch(`${BACKEND_BASE_URL}/api/user/me`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  })

  if (!response.ok) {
    throw new Error(await readErrorMessage(response))
  }

  return parseUserProfile((await response.json()) as Record<string, unknown>)
}

export async function updateUserPremium(accessToken: string, premium: boolean) {
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

export async function chargeUserCoins(accessToken: string, amount: number) {
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

export async function fetchUserBookmarks(accessToken: string) {
  const response = await fetch(`${BACKEND_BASE_URL}/api/user/me/bookmarks`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  })

  if (!response.ok) {
    throw new Error(await readErrorMessage(response))
  }

  return parseUserBookmarks((await response.json()) as Record<string, unknown>)
}

export async function addUserBookmark(accessToken: string, restaurant: Restaurant) {
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

export async function deleteUserBookmark(accessToken: string, storeId: string) {
  const response = await fetch(
    `${BACKEND_BASE_URL}/api/user/me/bookmarks/${encodeURIComponent(storeId)}`,
    {
      method: 'DELETE',
      headers: { Authorization: `Bearer ${accessToken}` },
    },
  )

  if (!response.ok) {
    throw new Error(await readErrorMessage(response))
  }

  return parseUserBookmarks((await response.json()) as Record<string, unknown>)
}

export async function fetchRecentAnalyses(accessToken: string) {
  const response = await fetch(`${BACKEND_BASE_URL}/api/user/me/recent-analyses`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  })

  if (!response.ok) {
    throw new Error(await readErrorMessage(response))
  }

  return parseRecentAnalyses((await response.json()) as Record<string, unknown>)
}
