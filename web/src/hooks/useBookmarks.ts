import { useEffect, useState } from 'react'
import {
  dedupeBookmarkRestaurants,
  getRestaurantStoreId,
  type Restaurant,
} from '../lib/restaurant'
import {
  addUserBookmark,
  deleteUserBookmark,
  fetchUserBookmarks,
  type ApiAuthHeaders,
  type UserBookmarks,
} from '../api/user'

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
  applyLocalBookmarkState: (restaurants: Restaurant[]) => void
}

export function useBookmarks(
  authHeaders: ApiAuthHeaders,
  authKey: string,
  showToast: (message: string) => void,
): UseBookmarksReturn {
  const [bookmarkedRestaurants, setBookmarkedRestaurants] = useState<Restaurant[]>([])
  const [bookmarkedStoreIds, setBookmarkedStoreIds] = useState<string[]>([])

  function applyRemoteBookmarkState(bookmarks: UserBookmarks) {
    setBookmarkedStoreIds(bookmarks.storeIds)
    setBookmarkedRestaurants(bookmarks.restaurants)
  }

  function applyLocalBookmarkState(restaurants: Restaurant[]) {
    const nextRestaurants = dedupeBookmarkRestaurants(restaurants)
    setBookmarkedRestaurants(nextRestaurants)
    setBookmarkedStoreIds(getBookmarkStoreIds(nextRestaurants))
  }

  useEffect(() => {
    if (!authKey) {
      const resetTimer = window.setTimeout(() => applyLocalBookmarkState([]), 0)
      return () => window.clearTimeout(resetTimer)
    }

    let canceled = false

    async function syncBookmarks() {
      try {
        const bookmarks = await fetchUserBookmarks(authHeaders)
        if (!canceled) applyRemoteBookmarkState(bookmarks)
      } catch (error) {
        if (canceled) return
        showToast(
          error instanceof Error
            ? `북마크 동기화 실패: ${error.message}`
            : '북마크 동기화에 실패했습니다',
        )
      }
    }

    void syncBookmarks()
    return () => { canceled = true }
  }, [authHeaders, authKey])

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

    if (!authKey) {
      showToast(bookmarked ? '북마크에서 해제되었습니다' : '북마크에 저장했습니다')
      return
    }

    try {
      const bookmarks = bookmarked
        ? await deleteUserBookmark(authHeaders, storeId)
        : await addUserBookmark(authHeaders, restaurant)
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
