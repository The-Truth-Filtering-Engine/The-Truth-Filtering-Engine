import { flushSync } from 'react-dom'
import { useState, useRef } from 'react'
import {
  fetchDetailJson,
  streamReviews,
  buildReviewSearchPath,
  parseBlogReview,
  buildKeywords,
  mergeReviews,
  isAnalysisUsageRequiredError,
  type DetailData,
  type AnalysisUsage,
  REVIEW_BATCH_SIZE,
  REVIEW_PAGE_SIZE,
  MAX_REVIEW_RESULTS,
} from '../api/reviews'
import { parseUserProfile } from '../api/user'
import { type Restaurant } from '../lib/restaurant'

export type DetailState = 'idle' | 'loading' | 'analyzing' | 'loaded' | 'noData' | 'error'

const ANALYSIS_USAGE_REQUIRED_MESSAGE = '추가분석을 위해 코인을 충전해 주세요'

export type UseDetailReturn = {
  detailState: DetailState
  detailData: DetailData | null
  detailErrorMessage: string
  reviewSort: 'real' | 'latest'
  reviewPage: number
  detailHasMoreReviews: boolean
  isReviewBatchLoading: boolean
  sortedDetailReviews: ReturnType<typeof getSortedReviews>
  reviewTotalPages: number
  visibleDetailReviews: ReturnType<typeof getSortedReviews>
  showReviewPageSkeleton: boolean
  loadRestaurantDetail: (restaurant: Restaurant, forceFresh?: boolean) => Promise<void>
  loadReviewBatchForPage: (pageIndex: number, restaurant: Restaurant) => Promise<void>
  changeReviewPage: (nextPage: number, restaurant: Restaurant) => void
  changeReviewSort: (nextSort: 'real' | 'latest') => void
  applyUsageProfile: (usage?: AnalysisUsage) => void
  onProfileUpdate: ((updater: (prev: unknown) => unknown) => void) | null
}

function getSortedReviews(reviews: ReturnType<typeof parseBlogReview>[], sort: 'real' | 'latest') {
  return [...reviews].sort((a, b) => {
    if (sort === 'latest') return b.date.localeCompare(a.date) || b.id - a.id
    return a.adProbability - b.adProbability || b.id - a.id
  })
}

export function useDetail(
  authHeaders: Record<string, string>,
  showToast: (message: string) => void,
  onProfileRefresh: (profile: ReturnType<typeof parseUserProfile>) => void,
) {
  const [detailState, setDetailState] = useState<DetailState>('idle')
  const [detailData, setDetailData] = useState<DetailData | null>(null)
  const [detailErrorMessage, setDetailErrorMessage] = useState('')
  const [reviewSort, setReviewSort] = useState<'real' | 'latest'>('real')
  const [reviewPage, setReviewPage] = useState(0)
  const [detailHasMoreReviews, setDetailHasMoreReviews] = useState(false)
  const [isReviewBatchLoading, setIsReviewBatchLoading] = useState(false)
  const detailRequestIdRef = useRef(0)
  const reviewBatchRequestIdRef = useRef(0)
  const streamControllerRef = useRef<AbortController | null>(null)

  function applyUsageProfile(usage?: AnalysisUsage) {
    const profile = usage?.profile
    if (!profile) return
    onProfileRefresh(parseUserProfile(profile))
  }

  async function loadRestaurantDetail(restaurant: Restaurant, forceFresh = false) {
    streamControllerRef.current?.abort()
    const controller = new AbortController()
    streamControllerRef.current = controller
    const requestId = ++detailRequestIdRef.current
    const query = restaurant.name

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
          buildReviewSearchPath('/api/search/cached', query, { restaurant }),
          controller.signal,
          authHeaders,
        )
        if (requestId !== detailRequestIdRef.current) return

        if ((cached.reviews ?? []).length >= REVIEW_BATCH_SIZE) {
          detailJson = cached
        } else {
          setDetailState('analyzing')
          let streamedReviews: ReturnType<typeof parseBlogReview>[] = []
          try {
            for await (const chunk of streamReviews(
              buildReviewSearchPath('/api/search/stream', query, { naverStart: 1, restaurant }),
              controller.signal,
              authHeaders,
            )) {
              if (requestId !== detailRequestIdRef.current) return
              const batch = (chunk.reviews ?? []).map(parseBlogReview)
              streamedReviews = mergeReviews(streamedReviews, batch)
              if (streamedReviews.length > 0) {
                flushSync(() => {
                  setDetailData({ reviews: [...streamedReviews], keywords: buildKeywords(streamedReviews) })
                  setDetailState('loaded')
                })
              }
              if (chunk.done) break
            }
          } catch (error) {
            if (isAnalysisUsageRequiredError(error)) throw error
            if ((cached.reviews ?? []).length === 0) throw error
            showToast('추가 리뷰를 불러오지 못해 저장된 리뷰만 표시합니다')
          }
          if (requestId !== detailRequestIdRef.current) return
          if (streamedReviews.length === 0 && (cached.reviews ?? []).length === 0) {
            setDetailState('noData')
            return
          }
          setDetailHasMoreReviews(false)
          return
        }
      } else {
        setDetailState('analyzing')
        let streamedReviews: ReturnType<typeof parseBlogReview>[] = []
        for await (const chunk of streamReviews(
          buildReviewSearchPath('/api/search/stream', query, { naverStart: 1, refresh: true, restaurant }),
          controller.signal,
          authHeaders,
        )) {
          if (requestId !== detailRequestIdRef.current) return
          const batch = (chunk.reviews ?? []).map(parseBlogReview)
          streamedReviews = mergeReviews(streamedReviews, batch)
          if (streamedReviews.length > 0) {
            flushSync(() => {
              setDetailData({ reviews: [...streamedReviews], keywords: buildKeywords(streamedReviews) })
              setDetailState('loaded')
            })
          }
          if (chunk.done) break
        }
        if (requestId !== detailRequestIdRef.current) return
        if (streamedReviews.length === 0) {
          setDetailState('noData')
          return
        }
        setDetailHasMoreReviews(false)
        return
      }

      if (requestId !== detailRequestIdRef.current) return

      applyUsageProfile(detailJson.usage)

      const reviews = (detailJson.reviews ?? []).map(parseBlogReview)
      if (reviews.length === 0) {
        setDetailState('noData')
        return
      }

      setDetailData({ reviews, keywords: buildKeywords(reviews) })
      setDetailHasMoreReviews(
        Boolean(detailJson.hasMore) && reviews.length < MAX_REVIEW_RESULTS,
      )
      setDetailState('loaded')
    } catch (error) {
      if (requestId !== detailRequestIdRef.current) return
      const message =
        error instanceof Error ? error.message : '상세 데이터를 불러오지 못했습니다'
      setDetailErrorMessage(message)
      if (isAnalysisUsageRequiredError(error)) {
        showToast(message || ANALYSIS_USAGE_REQUIRED_MESSAGE)
      }
      setDetailState('error')
    }
  }

  async function loadReviewBatchForPage(pageIndex: number, restaurant: Restaurant) {
    if (!detailData || !detailHasMoreReviews || isReviewBatchLoading) return

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
        buildReviewSearchPath('/api/search', restaurant.name, {
          naverStart,
          restaurant,
        }),
        controller.signal,
        authHeaders,
      )
      if (requestId !== reviewBatchRequestIdRef.current) return

      applyUsageProfile(detailJson.usage)

      const nextReviews = (detailJson.reviews ?? []).map(parseBlogReview)
      const reviews = mergeReviews(detailData.reviews, nextReviews)

      setDetailData({ reviews, keywords: buildKeywords(reviews) })
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

  const sortedDetailReviews = detailData ? getSortedReviews(detailData.reviews, reviewSort) : []
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
    : sortedDetailReviews.slice(reviewPageStart, reviewPageStart + REVIEW_PAGE_SIZE)

  function changeReviewPage(nextPage: number, restaurant: Restaurant) {
    const normalizedPage = Math.max(0, Math.min(nextPage, reviewTotalPages - 1))
    setReviewPage(normalizedPage)

    if (normalizedPage * REVIEW_PAGE_SIZE >= sortedDetailReviews.length && detailHasMoreReviews) {
      loadReviewBatchForPage(normalizedPage, restaurant)
    }
  }

  function changeReviewSort(nextSort: 'real' | 'latest') {
    setReviewSort(nextSort)
    setReviewPage(0)
  }

  return {
    detailState,
    detailData,
    detailErrorMessage,
    reviewSort,
    reviewPage,
    detailHasMoreReviews,
    isReviewBatchLoading,
    sortedDetailReviews,
    reviewTotalPages,
    visibleDetailReviews,
    showReviewPageSkeleton,
    loadRestaurantDetail,
    loadReviewBatchForPage,
    changeReviewPage,
    changeReviewSort,
    applyUsageProfile,
  }
}
