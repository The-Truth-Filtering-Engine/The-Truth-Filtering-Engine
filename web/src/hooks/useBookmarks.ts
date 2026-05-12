import { type Session } from '@supabase/supabase-js'
import { useEffect, useRef, useState } from 'react'
import {
  dedupeBookmarkRestaurants,
  getRestaurantStoreId,
  normalizeRestaurant,
  type Restaurant,
} from '../lib/restaurant'
import {
  addUserBookmark,
  deleteUserBookmark,
  fetchUserBookmarks,
  type UserBookmarks,
} from '../api/user'

const BOOKMARK_STORAGE_KEY = 'bookmarked_restaurants'

export function loadBookmarkedRestaurants(): Restaurant[] {
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
  window.localStorage.setItem(BOOKMARK_STORAGE_KEY, JSON.stringify(bookmarkedRestaurants))
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

export type UseBookmarksReturn = {
  bookmarkedRestaurants: Restaurant[]
  bookmarkedStoreIds: string[]
  toggleBookmark: (restaurant: Restaurant) => Promise<void>
  applyRemoteBookmarkState: (bookmarks: UserBookmarks) => void
  applyLocalBookmarkState: (restaurants: Restaurant[], shouldSave?: boolean) => void
}

export function useBookmarks(
  authSession: Session | null,
  isTemporaryAdmin: boolean,
  showToast: (message: string) => void,
): UseBookmarksReturn {
  const initialBookmarks = loadBookmarkedRestaurants()
  const [bookmarkedRestaurants, setBookmarkedRestaurants] = useState<Restaurant[]>(initialBookmarks)
  const [bookmarkedStoreIds, setBookmarkedStoreIds] = useState<string[]>(
    getBookmarkStoreIds(initialBookmarks),
  )
  const bookmarkSyncSessionRef = useRef<string | null>(null)

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

  useEffect(() => {
    const token = authSession?.access_token
    if (!token) {
      if (isTemporaryAdmin) {
        applyLocalBookmarkState(loadBookmarkedRestaurants())
      }
      return
    }

    let canceled = false
    const sessionKey = authSession.user?.id || token

    async function syncBookmarks() {
      try {
        let bookmarks = await fetchUserBookmarks(token)
        const localBookmarks = loadBookmarkedRestaurants()

        if (localBookmarks.length > 0 && bookmarkSyncSessionRef.current !== sessionKey) {
          for (const restaurant of localBookmarks) {
            const storeId = getRestaurantStoreId(restaurant)
            const hasRemoteStore = bookmarks.restaurants.some(
              (item) => getRestaurantStoreId(item) === storeId,
            )
            if (!storeId || (bookmarks.storeIds.includes(storeId) && hasRemoteStore)) {
              continue
            }
            bookmarks = await addUserBookmark(token, restaurant)
          }
          window.localStorage.removeItem(BOOKMARK_STORAGE_KEY)
        }

        bookmarkSyncSessionRef.current = sessionKey
        if (!canceled) applyRemoteBookmarkState(bookmarks)
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
    return () => { canceled = true }
  }, [authSession?.access_token, authSession?.user?.id, isTemporaryAdmin])

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
      ? previousRestaurants.filter((item) => getRestaurantStoreId(item) !== storeId)
      : dedupeBookmarkRestaurants([
          restaurant,
          ...previousRestaurants.filter((item) => getRestaurantStoreId(item) !== storeId),
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

  return {
    bookmarkedRestaurants,
    bookmarkedStoreIds,
    toggleBookmark,
    applyRemoteBookmarkState,
    applyLocalBookmarkState,
  }
}

export { getBookmarkStoreIds }
